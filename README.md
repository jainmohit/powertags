# Terraform PowerTag Module for EC2 Instance Automation

A comprehensive Terraform module that provides automated start/stop functionality for EC2 instances using tag-based scheduling. This module helps optimize AWS costs by automatically managing instance lifecycles based on configurable schedules.

## Features

- 🚀 **Automated Start/Stop**: Schedule EC2 instances to start and stop automatically
- 🏷️ **Tag-Based Control**: Use PowerTag tags to configure instance behavior
- ⏰ **Flexible Scheduling**: Support for various day patterns and time ranges
- 💰 **Cost Optimization**: Reduce AWS costs by running instances only when needed
- 📊 **Monitoring**: CloudWatch logs and metrics for all operations
- 🔒 **Security**: Least-privilege IAM policies with resource-level permissions
- 🎯 **Selective Management**: Only manages instances with PowerTagEnabled=true

## Architecture

\`\`\`
CloudWatch Events → Lambda Functions → EC2 Instances
                                    ↓
                              PowerTag Tags
\`\`\`

## Quick Start

```hcl
module "ec2_powertag" {
  source = "./terraform-powertag-ec2"

  # Basic Configuration
  name_prefix       = "dev-servers"
  instance_count    = 2
  ami_id            = "ami-0c55b159cbfafe1f0"
  subnet_id         = "subnet-12345678"
  security_group_ids = ["sg-12345678"]
  
  # PowerTag Schedule Configuration
  power_tag_start_time  = "0800"  # 8:00 AM UTC
  power_tag_stop_time   = "1800"  # 6:00 PM UTC
  power_tag_days_active = "Mon-Fri"
  
  # CloudWatch Schedule (Cron expressions)
  start_cron_expression = "0 8 ? * MON-FRI *"
  stop_cron_expression  = "0 18 ? * MON-FRI *"

  common_tags = {
    Environment = "Development"
    Project     = "CostOptimization"
    Owner       = "DevOps Team"
  }
}
