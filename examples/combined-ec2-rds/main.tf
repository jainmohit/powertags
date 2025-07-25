# Combined EC2 and RDS PowerTag example with different schedules

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

# Web Servers (9 AM - 6 PM, Mon-Fri)
module "web_servers" {
  source = "../../modules/ec2"

  name_prefix    = "web-servers"
  instance_count = 3
  ami_id         = data.aws_ami.amazon_linux.id
  instance_type  = "t3.small"
  subnet_id      = data.aws_subnets.default.ids[0]
  security_group_ids = [data.aws_security_group.default.id]
  
  power_tag_start_time  = "0900"
  power_tag_stop_time   = "1800"
  power_tag_days_active = "Mon-Fri"
  start_cron_expression = "0 9 ? * MON-FRI *"
  stop_cron_expression  = "0 18 ? * MON-FRI *"

  common_tags = {
    Environment = "Production"
    Tier        = "Web"
    Project     = "PowerTag-Combined"
  }
}

# Database Servers (8 AM - 7 PM, Mon-Fri)
module "database_servers" {
  source = "../../modules/rds"

  name_prefix    = "app-database"
  instance_count = 1
  
  engine         = "postgres"
  engine_version = "13.7"
  instance_class = "db.t3.small"
  username       = "dbadmin"
  password       = var.db_password
  
  subnet_ids             = data.aws_subnets.default.ids
  vpc_security_group_ids = [data.aws_security_group.default.id]
  
  power_tag_start_time  = "0800"
  power_tag_stop_time   = "1900"
  power_tag_days_active = "Mon-Fri"
  start_cron_expression = "0 8 ? * MON-FRI *"
  stop_cron_expression  = "0 19 ? * MON-FRI *"

  common_tags = {
    Environment = "Production"
    Tier        = "Database"
    Project     = "PowerTag-Combined"
  }
}

# Development Environment (10 AM - 4 PM, Mon-Thu)
module "dev_environment" {
  source = "../../modules/ec2"

  name_prefix    = "dev-env"
  instance_count = 2
  ami_id         = data.aws_ami.amazon_linux.id
  instance_type  = "t3.micro"
  subnet_id      = data.aws_subnets.default.ids[0]
  security_group_ids = [data.aws_security_group.default.id]
  
  power_tag_start_time  = "1000"
  power_tag_stop_time   = "1600"
  power_tag_days_active = "Mon,Tue,Wed,Thu"
  start_cron_expression = "0 10 ? * MON-THU *"
  stop_cron_expression  = "0 16 ? * MON-THU *"

  common_tags = {
    Environment = "Development"
    Tier        = "Application"
    Project     = "PowerTag-Combined"
  }
}

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
output "infrastructure_summary" {
  description = "Complete infrastructure summary"
  value = {
    web_servers = {
      instance_count = length(module.web_servers.instance_ids)
      schedule       = module.web_servers.powertag_configuration
      savings        = module.web_servers.cost_optimization_summary
    }
    database = {
      instance_count = length(module.database_servers.instance_ids)
      schedule       = module.database_servers.powertag_configuration
      savings        = module.database_servers.cost_optimization_summary
    }
    dev_environment = {
      instance_count = length(module.dev_environment.instance_ids)
      schedule       = module.dev_environment.powertag_configuration
      savings        = module.dev_environment.cost_optimization_summary
    }
  }
}
