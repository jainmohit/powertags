# Terraform PowerTag EC2 Module Variables

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "powertag"
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.name_prefix))
    error_message = "Name prefix must start with a letter and contain only alphanumeric characters and hyphens."
  }
}

variable "instance_count" {
  description = "Number of EC2 instances to create"
  type        = number
  default     = 1
  
  validation {
    condition     = var.instance_count > 0 && var.instance_count <= 50
    error_message = "Instance count must be between 1 and 50."
  }
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
  
  validation {
    condition     = can(regex("^ami-[a-z0-9]{8,17}$", var.ami_id))
    error_message = "AMI ID must be a valid format (ami-xxxxxxxx)."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "Subnet ID for EC2 instances"
  type        = string
  
  validation {
    condition     = can(regex("^subnet-[a-z0-9]{8,17}$", var.subnet_id))
    error_message = "Subnet ID must be a valid format (subnet-xxxxxxxx)."
  }
}

variable "security_group_ids" {
  description = "Security group IDs for EC2 instances"
  type        = list(string)
  
  validation {
    condition = alltrue([
      for sg in var.security_group_ids : can(regex("^sg-[a-z0-9]{8,17}$", sg))
    ])
    error_message = "All security group IDs must be valid format (sg-xxxxxxxx)."
  }
}

variable "key_name" {
  description = "SSH key name for EC2 instances"
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 20
  
  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 1000
    error_message = "Root volume size must be between 8 and 1000 GB."
  }
}

variable "root_volume_type" {
  description = "Type of the root volume"
  type        = string
  default     = "gp3"
  
  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2"], var.root_volume_type)
    error_message = "Root volume type must be one of: gp2, gp3, io1, io2."
  }
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

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
  default     = 60
  
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

variable "enable_detailed_monitoring" {
  description = "Enable detailed monitoring for EC2 instances"
  type        = bool
  default     = false
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
