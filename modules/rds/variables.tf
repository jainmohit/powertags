# Terraform PowerTag RDS Module Variables

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "powertag-rds"
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.name_prefix))
    error_message = "Name prefix must start with a letter and contain only alphanumeric characters and hyphens."
  }
}

variable "instance_count" {
  description = "Number of RDS instances to create"
  type        = number
  default     = 1
  
  validation {
    condition     = var.instance_count > 0 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}

# Database Configuration
variable "engine" {
  description = "Database engine"
  type        = string
  default     = "mysql"
  
  validation {
    condition     = contains(["mysql", "postgres", "mariadb", "oracle-ee", "oracle-se2", "sqlserver-ex", "sqlserver-web", "sqlserver-se", "sqlserver-ee"], var.engine)
    error_message = "Engine must be a supported RDS engine type."
  }
}

variable "engine_version" {
  description = "Database engine version"
  type        = string
  default     = "8.0"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Initial allocated storage in GB"
  type        = number
  default     = 20
  
  validation {
    condition     = var.allocated_storage >= 20 && var.allocated_storage <= 65536
    error_message = "Allocated storage must be between 20 and 65536 GB."
  }
}

variable "max_allocated_storage" {
  description = "Maximum allocated storage for autoscaling in GB"
  type        = number
  default     = 100
}

variable "storage_type" {
  description = "Storage type"
  type        = string
  default     = "gp2"
  
  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2"], var.storage_type)
    error_message = "Storage type must be one of: gp2, gp3, io1, io2."
  }
}

variable "storage_encrypted" {
  description = "Enable storage encryption"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
  default     = null
}

# Database Credentials
variable "db_name" {
  description = "Name of the database"
  type        = string
  default     = "powertagdb"
}

variable "username" {
  description = "Master username"
  type        = string
  default     = "admin"
}

variable "password" {
  description = "Master password"
  type        = string
  sensitive   = true
}

# Network Configuration
variable "subnet_ids" {
  description = "List of subnet IDs for DB subnet group"
  type        = list(string)
  
  validation {
    condition = alltrue([
      for subnet in var.subnet_ids : can(regex("^subnet-[a-z0-9]{8,17}$", subnet))
    ])
    error_message = "All subnet IDs must be valid format (subnet-xxxxxxxx)."
  }
}

variable "vpc_security_group_ids" {
  description = "List of VPC security group IDs"
  type        = list(string)
  
  validation {
    condition = alltrue([
      for sg in var.vpc_security_group_ids : can(regex("^sg-[a-z0-9]{8,17}$", sg))
    ])
    error_message = "All security group IDs must be valid format (sg-xxxxxxxx)."
  }
}

variable "publicly_accessible" {
  description = "Make the RDS instance publicly accessible"
  type        = bool
  default     = false
}

variable "port" {
  description = "Database port"
  type        = number
  default     = null
}

# Backup Configuration
variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
  
  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "Backup retention period must be between 0 and 35 days."
  }
}

variable "backup_window" {
  description = "Backup window"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Maintenance window"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

# Monitoring
variable "monitoring_interval" {
  description = "Enhanced monitoring interval in seconds"
  type        = number
  default     = 0
  
  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "Monitoring interval must be one of: 0, 1, 5, 10, 15, 30, 60."
  }
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = false
}

# Deletion Protection
variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when deleting"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

# PowerTag Configuration
variable "power_tag_start_time" {
  description = "Time to start instances (HHMM format, e.g., '0800')"
  type        = string
  default     = "0800"
  
  validation {
    condition     = can(regex("^([01][0-9]|2[0-3])[0-5][0-9]$", var.power_tag_start_time))
    error_message = "Start time must be in HHMM format (e.g., '0800', '1430')."
  }
}

variable "power_tag_stop_time" {
  description = "Time to stop instances (HHMM format, e.g., '1800')"
  type        = string
  default     = "1800"
  
  validation {
    condition     = can(regex("^([01][0-9]|2[0-3])[0-5][0-9]$", var.power_tag_stop_time))
    error_message = "Stop time must be in HHMM format (e.g., '1800', '2130')."
  }
}

variable "power_tag_days_active" {
  description = "Days when instances should be active (e.g., 'Mon-Fri', 'Mon,Wed,Fri')"
  type        = string
  default     = "Mon-Fri"
  
  validation {
    condition = can(regex("^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)(-|,)(Mon|Tue|Wed|Thu|Fri|Sat|Sun)$|^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)(,(Mon|Tue|Wed|Thu|Fri|Sat|Sun))*$", var.power_tag_days_active))
    error_message = "Days active must be in format 'Mon-Fri' or 'Mon,Wed,Fri'."
  }
}

variable "start_cron_expression" {
  description = "Cron expression for starting instances"
  type        = string
  default     = "0 8 ? * MON-FRI *"
}

variable "stop_cron_expression" {
  description = "Cron expression for stopping instances"
  type        = string
  default     = "0 18 ? * MON-FRI *"
}

# Lambda Configuration
variable "lambda_runtime" {
  description = "Runtime for Lambda functions"
  type        = string
  default     = "python3.9"
  
  validation {
    condition     = contains(["python3.8", "python3.9", "python3.10", "python3.11"], var.lambda_runtime)
    error_message = "Lambda runtime must be one of: python3.8, python3.9, python3.10, python3.11."
  }
}

variable "lambda_timeout" {
  description = "Timeout for Lambda functions in seconds"
  type        = number
  default     = 300
  
  validation {
    condition     = var.lambda_timeout >= 3 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 3 and 900 seconds."
  }
}

variable "lambda_memory_size" {
  description = "Memory size for Lambda functions in MB"
  type        = number
  default     = 128
  
  validation {
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 10240
    error_message = "Lambda memory size must be between 128 and 10240 MB."
  }
}

variable "lambda_log_retention_days" {
  description = "CloudWatch log retention period for Lambda functions in days"
  type        = number
  default     = 14
  
  validation {
    condition = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.lambda_log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention period."
  }
}
