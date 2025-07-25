# Multi-environment example for PowerTag modules

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

# Data sources
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

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Development Environment
module "dev_ec2" {
  source = "../../modules/ec2"

  name_prefix    = "dev"
  instance_count = 1
  ami_id         = data.aws_ami.amazon_linux.id
  instance_type  = "t3.micro"
  subnet_id      = data.aws_subnets.default.ids[0]
  security_group_ids = [data.aws_security_group.default.id]
  
  # Dev schedule: 9 AM - 5 PM, weekdays only
  power_tag_start_time  = "0900"
  power_tag_stop_time   = "1700"
  power_tag_days_active = "Mon-Fri"
  start_cron_expression = "0 9 ? * MON-FRI *"
  stop_cron_expression  = "0 17 ? * MON-FRI *"

  common_tags = {
    Environment = "Development"
    Project     = "PowerTag-MultiEnv"
    CostCenter  = "Engineering"
  }
}

# Staging Environment
module "staging_ec2" {
  source = "../../modules/ec2"

  name_prefix    = "staging"
  instance_count = 2
  ami_id         = data.aws_ami.amazon_linux.id
  instance_type  = "t3.small"
  subnet_id      = data.aws_subnets.default.ids[0]
  security_group_ids = [data.aws_security_group.default.id]
  
  # Staging schedule: 8 AM - 8 PM, weekdays only
  power_tag_start_time  = "0800"
  power_tag_stop_time   = "2000"
  power_tag_days_active = "Mon-Fri"
  start_cron_expression = "0 8 ? * MON-FRI *"
  stop_cron_expression  = "0 20 ? * MON-FRI *"

  common_tags = {
    Environment = "Staging"
    Project     = "PowerTag-MultiEnv"
    CostCenter  = "Engineering"
  }
}

# Testing Environment (Weekend testing)
module "test_ec2" {
  source = "../../modules/ec2"

  name_prefix    = "test"
  instance_count = 1
  ami_id         = data.aws_ami.amazon_linux.id
  instance_type  = "t3.micro"
  subnet_id      = data.aws_subnets.default.ids[0]
  security_group_ids = [data.aws_security_group.default.id]
  
  # Test schedule: 10 AM - 4 PM, weekends only
  power_tag_start_time  = "1000"
  power_tag_stop_time   = "1600"
  power_tag_days_active = "Sat-Sun"
  start_cron_expression = "0 10 ? * SAT-SUN *"
  stop_cron_expression  = "0 16 ? * SAT-SUN *"

  common_tags = {
    Environment = "Testing"
    Project     = "PowerTag-MultiEnv"
    CostCenter  = "QA"
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# Outputs
output "environments" {
  description = "All environment details"
  value = {
    development = {
      instance_ids = module.dev_ec2.instance_ids
      config       = module.dev_ec2.powertag_configuration
    }
    staging = {
      instance_ids = module.staging_ec2.instance_ids
      config       = module.staging_ec2.powertag_configuration
    }
    testing = {
      instance_ids = module.test_ec2.instance_ids
      config       = module.test_ec2.powertag_configuration
    }
  }
}
