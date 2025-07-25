# RDS PowerTag Module - Main Configuration
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

# DB Subnet Group
resource "aws_db_subnet_group" "powertag_subnet_group" {
  name       = "${var.name_prefix}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-db-subnet-group"
    Type = "PowerTag-RDS"
  })
}

# RDS Instances with PowerTag configuration
resource "aws_db_instance" "powertag_instances" {
  count = var.instance_count

  # Basic Configuration
  identifier     = "${var.name_prefix}-db-${count.index + 1}"
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class
  
  # Database Configuration
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted
  kms_key_id           = var.kms_key_id
  
  # Database Credentials
  db_name  = var.db_name
  username = var.username
  password = var.password
  
  # Network Configuration
  db_subnet_group_name   = aws_db_subnet_group.powertag_subnet_group.name
  vpc_security_group_ids = var.vpc_security_group_ids
  publicly_accessible    = var.publicly_accessible
  port                   = var.port
  
  # Backup Configuration
  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window
  
  # Monitoring
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? aws_iam_role.rds_enhanced_monitoring[0].arn : null
  
  # Performance Insights
  performance_insights_enabled = var.performance_insights_enabled
  
  # Deletion Protection
  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot
  
  tags = merge(var.common_tags, {
    Name                  = "${var.name_prefix}-db-${count.index + 1}"
    PowerTagEnabled       = "true"
    PowerTagStartTime     = var.power_tag_start_time
    PowerTagStopTime      = var.power_tag_stop_time
    PowerTagDaysActive    = var.power_tag_days_active
    PowerTagModule        = "terraform-powertag-rds"
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

# Enhanced Monitoring IAM Role (if monitoring is enabled)
resource "aws_iam_role" "rds_enhanced_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0
  name  = "${var.name_prefix}-rds-enhanced-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-rds-monitoring-role"
    Type = "PowerTag-RDS-IAM"
  })
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  count      = var.monitoring_interval > 0 ? 1 : 0
  role       = aws_iam_role.rds_enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# CloudWatch Event Rule for starting instances
resource "aws_cloudwatch_event_rule" "start_instances" {
  name                = "${var.name_prefix}-start-rds-instances"
  description         = "Trigger Lambda to start PowerTag RDS instances"
  schedule_expression = "cron(${var.start_cron_expression})"
  
  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-rds-start-rule"
    Type = "PowerTag-RDS-Start"
  })
}

# CloudWatch Event Rule for stopping instances
resource "aws_cloudwatch_event_rule" "stop_instances" {
  name                = "${var.name_prefix}-stop-rds-instances"
  description         = "Trigger Lambda to stop PowerTag RDS instances"
  schedule_expression = "cron(${var.stop_cron_expression})"
  
  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-rds-stop-rule"
    Type = "PowerTag-RDS-Stop"
  })
}

# CloudWatch Event Target for start Lambda
resource "aws_cloudwatch_event_target" "start_lambda_target" {
  rule      = aws_cloudwatch_event_rule.start_instances.name
  target_id = "StartRDSInstancesLambdaTarget"
  arn       = aws_lambda_function.start_instances.arn
}

# CloudWatch Event Target for stop Lambda
resource "aws_cloudwatch_event_target" "stop_lambda_target" {
  rule      = aws_cloudwatch_event_rule.stop_instances.name
  target_id = "StopRDSInstancesLambdaTarget"
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
