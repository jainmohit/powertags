import json
import boto3
import os
from datetime import datetime, timedelta
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    AWS Lambda function to start or stop EC2 instances based on PowerTag configuration.
    
    Environment Variables:
    - ACTION: 'start' or 'stop'
    - REGION: AWS region
    """
    
    try:
        # Get environment variables
        action = os.environ.get('ACTION', 'start').lower()
        region = os.environ.get('REGION', 'us-east-1')
        
        logger.info(f"Starting PowerTag {action} operation in region {region}")
        
        # Initialize EC2 client
        ec2 = boto3.client('ec2', region_name=region)
        
        # Get current time and day
        current_time = datetime.utcnow()
        current_day = current_time.strftime('%a')  # Mon, Tue, Wed, etc.
        current_hour_minute = current_time.strftime('%H%M')
        
        logger.info(f"Current UTC time: {current_time}, Day: {current_day}, Time: {current_hour_minute}")
        
        # Find instances with PowerTag enabled
        instances = get_powertag_instances(ec2)
        
        if not instances:
            logger.info("No PowerTag enabled instances found")
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'No PowerTag enabled instances found',
                    'action': action,
                    'processed': 0
                })
            }
        
        processed_instances = []
        
        for instance in instances:
            instance_id = instance['InstanceId']
            instance_state = instance['State']['Name']
            tags = {tag['Key']: tag['Value'] for tag in instance.get('Tags', [])}
            
            # Get PowerTag configuration from tags
            start_time = tags.get('PowerTagStartTime', '0800')
            stop_time = tags.get('PowerTagStopTime', '1800')
            days_active = tags.get('PowerTagDaysActive', 'Mon-Fri')
            
            logger.info(f"Processing instance {instance_id}: State={instance_state}, "
                       f"StartTime={start_time}, StopTime={stop_time}, DaysActive={days_active}")
            
            # Check if today is an active day
            if not is_active_day(current_day, days_active):
                logger.info(f"Instance {instance_id}: Today ({current_day}) is not an active day ({days_active})")
                continue
            
            # Check if it's time to perform the action
            should_act = False
            
            if action == 'start':
                should_act = (
                    instance_state == 'stopped' and 
                    is_time_match(current_hour_minute, start_time)
                )
            elif action == 'stop':
                should_act = (
                    instance_state == 'running' and 
                    is_time_match(current_hour_minute, stop_time)
                )
            
            if should_act:
                try:
                    if action == 'start':
                        ec2.start_instances(InstanceIds=[instance_id])
                        tag_key = 'PowerTagLastStart'
                    else:
                        ec2.stop_instances(InstanceIds=[instance_id])
                        tag_key = 'PowerTagLastStop'
                    
                    # Add timestamp tag
                    ec2.create_tags(
                        Resources=[instance_id],
                        Tags=[
                            {
                                'Key': tag_key,
                                'Value': current_time.isoformat()
                            },
                            {
                                'Key': 'PowerTagLastAction',
                                'Value': f"{action}-{current_time.isoformat()}"
                            }
                        ]
                    )
                    
                    processed_instances.append({
                        'instance_id': instance_id,
                        'action': action,
                        'previous_state': instance_state,
                        'timestamp': current_time.isoformat()
                    })
                    
                    logger.info(f"Successfully {action}ed instance {instance_id}")
                    
                except Exception as e:
                    logger.error(f"Failed to {action} instance {instance_id}: {str(e)}")
            else:
                logger.info(f"Instance {instance_id}: No action needed (State={instance_state}, "
                           f"CurrentTime={current_hour_minute}, TargetTime={start_time if action == 'start' else stop_time})")
        
        logger.info(f"PowerTag {action} operation completed. Processed {len(processed_instances)} instances")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'PowerTag {action} operation completed successfully',
                'action': action,
                'processed': len(processed_instances),
                'instances': processed_instances,
                'timestamp': current_time.isoformat()
            })
        }
        
    except Exception as e:
        logger.error(f"PowerTag operation failed: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': f'PowerTag operation failed: {str(e)}',
                'action': action
            })
        }

def get_powertag_instances(ec2):
    """Get all instances with PowerTagEnabled=true"""
    try:
        response = ec2.describe_instances(
            Filters=[
                {
                    'Name': 'tag:PowerTagEnabled',
                    'Values': ['true']
                },
                {
                    'Name': 'instance-state-name',
                    'Values': ['running', 'stopped']
                }
            ]
        )
        
        instances = []
        for reservation in response['Reservations']:
            instances.extend(reservation['Instances'])
        
        return instances
        
    except Exception as e:
        logger.error(f"Failed to get PowerTag instances: {str(e)}")
        return []

def is_active_day(current_day, days_active):
    """Check if current day matches the PowerTag days active configuration"""
    
    day_mapping = {
        'Mon': 0, 'Tue': 1, 'Wed': 2, 'Thu': 3, 'Fri': 4, 'Sat': 5, 'Sun': 6
    }
    
    current_day_num = day_mapping.get(current_day, -1)
    if current_day_num == -1:
        return False
    
    # Handle range format (e.g., "Mon-Fri")
    if '-' in days_active:
        start_day, end_day = days_active.split('-')
        start_num = day_mapping.get(start_day.strip(), -1)
        end_num = day_mapping.get(end_day.strip(), -1)
        
        if start_num == -1 or end_num == -1:
            return False
        
        # Handle wrap-around (e.g., "Fri-Mon")
        if start_num <= end_num:
            return start_num <= current_day_num <= end_num
        else:
            return current_day_num >= start_num or current_day_num <= end_num
    
    # Handle comma-separated format (e.g., "Mon,Wed,Fri")
    elif ',' in days_active:
        active_days = [day.strip() for day in days_active.split(',')]
        return current_day in active_days
    
    # Handle single day
    else:
        return current_day == days_active.strip()

def is_time_match(current_time, target_time, tolerance_minutes=5):
    """Check if current time matches target time within tolerance"""
    
    try:
        # Parse times
        current_hour = int(current_time[:2])
        current_minute = int(current_time[2:])
        target_hour = int(target_time[:2])
        target_minute = int(target_time[2:])
        
        # Convert to minutes since midnight
        current_total_minutes = current_hour * 60 + current_minute
        target_total_minutes = target_hour * 60 + target_minute
        
        # Check if within tolerance
        time_diff = abs(current_total_minutes - target_total_minutes)
        
        return time_diff <= tolerance_minutes
        
    except (ValueError, IndexError):
        logger.error(f"Invalid time format: current={current_time}, target={target_time}")
        return False
