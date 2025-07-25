# Basic usage example for PowerTag modules

terraform {
  required_version = ">= 0.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources for existing infrastructure
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_security_group" "default" {
  name   = "default"
  vpc_id = data.aws_vpc.default.id
}

# Get the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# PowerTag EC2 Module
module "powertag_ec2" {
  source = "../../modules/ec2"

  # Basic Configuration
  name_prefix    = "dev-servers"
  instance_count = 2
  ami_id         = data.aws_ami.amazon_linux.id
  instance_type  = "t3.micro"
  subnet_id      = data.aws_subnets.default.ids[0]
  security_group_ids = [data.aws_security_group.default.id]
  
  # PowerTag Schedule Configuration
  power_tag_start_time  = "0800"  # 8:00 AM UTC
  power_tag_stop_time   = "1800"  # 6:00 PM UTC
  power_tag_days_active = "Mon-Fri"
  
  # CloudWatch Schedule (Cron expressions)
  start_cron_expression = "0 8 ? * MON-FRI *"
  stop_cron_expression  = "0 18 ? * MON-FRI *"

  # Common tags
  common_tags = {
    Environment = "Development"
    Project     = "PowerTag-Demo"
    Owner       = "DevOps-Team"
    ManagedBy   = "Terraform"
  }
}

# PowerTag RDS Module
module "powertag_rds" {
  source = "../../modules/rds"

  # Basic Configuration
  name_prefix    = "dev-database"
  instance_count = 1
  
  # Database Configuration
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"
  username       = "admin"
  password       = var.db_password
  
  # Network Configuration
  subnet_ids             = data.aws_subnets.default.ids
  vpc_security_group_ids = [data.aws_security_group.default.id]
  
  # PowerTag Schedule Configuration
  power_tag_start_time  = "0800"  # 8:00 AM UTC
  power_tag_stop_time   = "1800"  # 6:00 PM UTC
  power_tag_days_active = "Mon-Fri"
  
  # CloudWatch Schedule (Cron expressions)
  start_cron_expression = "0 8 ? * MON-FRI *"
  stop_cron_expression  = "0 18 ? * MON-FRI *"

  # Common tags
  common_tags = {
    Environment = "Development"
    Project     = "PowerTag-Demo"
    Owner       = "DevOps-Team"
    ManagedBy   = "Terraform"
  }
}

# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

# Outputs
output "ec2_instances" {
  description = "EC2 instance details"
  value = {
    instance_ids = module.powertag_ec2.instance_ids
    config       = module.powertag_ec2.powertag_configuration
  }
}

output "rds_instances" {
  description = "RDS instance details"
  value = {
    instance_ids = module.powertag_rds.instance_ids
    endpoints    = module.powertag_rds.instance_endpoints
    config       = module.powertag_rds.powertag_configuration
  }
}

output "lambda_functions" {
  description = "Lambda function details"
  value = {
    ec2 = {
      start_function = module.powertag_ec2.start_lambda_function_name
      stop_function  = module.powertag_ec2.stop_lambda_function_name
    }
    rds = {
      start_function = module.powertag_rds.start_lambda_function_name
      stop_function  = module.powertag_rds.stop_lambda_function_name
    }
  }
}
