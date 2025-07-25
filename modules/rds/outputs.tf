# Output values for the PowerTag RDS module

output "instance_ids" {
  description = "IDs of the created RDS instances"
  value       = aws_db_instance.powertag_instances[*].id
}

output "instance_endpoints" {
  description = "Endpoints of the created RDS instances"
  value       = aws_db_instance.powertag_instances[*].endpoint
}

output "instance_arns" {
  description = "ARNs of the created RDS instances"
  value       = aws_db_instance.powertag_instances[*].arn
}

output "instance_ports" {
  description = "Ports of the created RDS instances"
  value       = aws_db_instance.powertag_instances[*].port
}

output "start_lambda_arn" {
  description = "ARN of the Lambda function for starting instances"
  value       = aws_lambda_function.start_instances.arn
}

output "stop_lambda_arn" {
  description = "ARN of the Lambda function for stopping instances"
  value       = aws_lambda_function.stop_instances.arn
}

output "start_lambda_function_name" {
  description = "Name of the Lambda function for starting instances"
  value       = aws_lambda_function.start_instances.function_name
}

output "stop_lambda_function_name" {
  description = "Name of the Lambda function for stopping instances"
  value       = aws_lambda_function.stop_instances.function_name
}

output "start_schedule_expression" {
  description = "Schedule expression for starting instances"
  value       = aws_cloudwatch_event_rule.start_instances.schedule_expression
}

output "stop_schedule_expression" {
  description = "Schedule expression for stopping instances"
  value       = aws_cloudwatch_event_rule.stop_instances.schedule_expression
}

output "iam_role_arn" {
  description = "ARN of the IAM role used by Lambda functions"
  value       = aws_iam_role.lambda_powertag_role.arn
}

output "iam_role_name" {
  description = "Name of the IAM role used by Lambda functions"
  value       = aws_iam_role.lambda_powertag_role.name
}

output "cloudwatch_log_group_start" {
  description = "CloudWatch log group for start Lambda function"
  value       = aws_cloudwatch_log_group.start_lambda_logs.name
}

output "cloudwatch_log_group_stop" {
  description = "CloudWatch log group for stop Lambda function"
  value       = aws_cloudwatch_log_group.stop_lambda_logs.name
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group"
  value       = aws_db_subnet_group.powertag_subnet_group.name
}

output "powertag_configuration" {
  description = "PowerTag configuration summary"
  value = {
    start_time     = var.power_tag_start_time
    stop_time      = var.power_tag_stop_time
    days_active    = var.power_tag_days_active
    instance_count = var.instance_count
    name_prefix    = var.name_prefix
    engine         = var.engine
    instance_class = var.instance_class
  }
}

output "cost_optimization_summary" {
  description = "Estimated cost optimization details"
  value = {
    instances_managed               = var.instance_count
    schedule_type                  = var.power_tag_days_active
    daily_runtime_hours           = local.daily_runtime_hours
    estimated_monthly_savings_percent = local.estimated_savings_percent
  }
}

# Local values for calculations
locals {
  start_hour   = tonumber(substr(var.power_tag_start_time, 0, 2))
  start_minute = tonumber(substr(var.power_tag_start_time, 2, 2))
  stop_hour    = tonumber(substr(var.power_tag_stop_time, 0, 2))
  stop_minute  = tonumber(substr(var.power_tag_stop_time, 2, 2))
  
  daily_runtime_minutes = (local.stop_hour * 60 + local.stop_minute) - (local.start_hour * 60 + local.start_minute)
  daily_runtime_hours   = local.daily_runtime_minutes / 60
  
  estimated_savings_percent = var.power_tag_days_active == "Mon-Fri" ? 
    round((1 - (local.daily_runtime_hours * 5) / (24 * 7)) * 100) :
    var.power_tag_days_active == "Mon-Sun" ?
    round((1 - local.daily_runtime_hours / 24) * 100) :
    50  # Default estimate for custom schedules
}
