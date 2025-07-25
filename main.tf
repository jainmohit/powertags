# EC2 PowerTag Module - Main Configuration
terraform {
  required_version = ">= 0.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0.0"
    }
  }
}

# Data source for current AWS region
data "aws_region" "current" {}

# Data source for current AWS caller identity
data "aws_caller_identity" "current" {}

# EC2 Instances with PowerTag configuration
resource "aws_instance" "powertag_instances" {
  count                  = var.instance_count
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.key_name

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type
    encrypted   = true
  }

  tags = merge(var.common_tags, {
    Name                  = "${var.name_prefix}-instance-${count.index + 1}"
    PowerTagEnabled       = "true"
    PowerTagStartTime     = var.power_tag_start_time
    PowerTagStopTime      = var.power_tag_stop_time
    PowerTagDaysActive    = var.power_tag_days_active
    PowerTagModule        = "terraform-powertag-ec2"
    PowerTagCreatedBy     = "terraform"
    PowerTagCreatedAt     = timestamp()
  })

  lifecycle {
    ignore_changes = [
      tags["PowerTagLastStart"],
      tags["PowerTagLastStop"],
      tags["PowerTagLastAction"]
    ]
  }
}

# CloudWatch Event Rule for starting instances
resource "aws_cloudwatch_event_rule" "start_instances" {
  name                = "${var.name_prefix}-start-instances"
  description         = "Trigger Lambda to start PowerTag instances"
  schedule_expression = "cron(${var.start_cron_expression})"
  
  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-start-rule"
    Type = "PowerTag-Start"
  })
}

# CloudWatch Event Rule for stopping instances
resource "aws_cloudwatch_event_rule" "stop_instances" {
  name                = "${var.name_prefix}-stop-instances"
  description         = "Trigger Lambda to stop PowerTag instances"
  schedule_expression = "cron(${var.stop_cron_expression})"
  
  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-stop-rule"
    Type = "PowerTag-Stop"
  })
}

# CloudWatch Event Target for start Lambda
resource "aws_cloudwatch_event_target" "start_lambda_target" {
  rule      = aws_cloudwatch_event_rule.start_instances.name
  target_id = "StartInstancesLambdaTarget"
  arn       = aws_lambda_function.start_instances.arn
}

# CloudWatch Event Target for stop Lambda
resource "aws_cloudwatch_event_target" "stop_lambda_target" {
  rule      = aws_cloudwatch_event_rule.stop_instances.name
  target_id = "StopInstancesLambdaTarget"
  arn       = aws_lambda_function.stop_instances.arn
}

# Lambda permission for CloudWatch Events to invoke start function
resource "aws_lambda_permission" "allow_cloudwatch_start" {
  statement_id  = "AllowExecutionFromCloudWatchStart"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_instances.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.start_instances.arn
}

# Lambda permission for CloudWatch Events to invoke stop function
resource "aws_lambda_permission" "allow_cloudwatch_stop" {
  statement_id  = "AllowExecutionFromCloudWatchStop"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stop_instances.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stop_instances.arn
}
