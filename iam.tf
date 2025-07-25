# IAM Role for Lambda Functions
resource "aws_iam_role" "lambda_powertag_role" {
  name = "${var.name_prefix}-lambda-powertag-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-lambda-role"
    Type = "PowerTag-IAM"
  })
}

# IAM Policy for EC2 PowerTag Operations
resource "aws_iam_policy" "lambda_powertag_policy" {
  name        = "${var.name_prefix}-lambda-powertag-policy"
  description = "IAM policy for PowerTag Lambda functions to manage EC2 instances"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeInstanceAttribute",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:StartInstances",
          "ec2:StopInstances"
        ]
        Resource = "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/*"
        Condition = {
          StringEquals = {
            "ec2:ResourceTag/PowerTagEnabled" = "true"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"
        ]
        Resource = "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/*"
        Condition = {
          StringEquals = {
            "ec2:ResourceTag/PowerTagEnabled" = "true"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.name_prefix}-*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-lambda-policy"
    Type = "PowerTag-IAM"
  })
}

# Attach the PowerTag policy to the Lambda role
resource "aws_iam_role_policy_attachment" "lambda_powertag_policy_attachment" {
  role       = aws_iam_role.lambda_powertag_role.name
  policy_arn = aws_iam_policy.lambda_powertag_policy.arn
}

# Attach basic Lambda execution role policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_powertag_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Optional: IAM policy for enhanced monitoring (if enabled)
resource "aws_iam_policy" "lambda_enhanced_monitoring" {
  count       = var.enable_detailed_monitoring ? 1 : 0
  name        = "${var.name_prefix}-lambda-enhanced-monitoring"
  description = "Enhanced monitoring permissions for PowerTag Lambda functions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.name_prefix}-*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-enhanced-monitoring-policy"
    Type = "PowerTag-IAM"
  })
}

# Attach enhanced monitoring policy if enabled
resource "aws_iam_role_policy_attachment" "lambda_enhanced_monitoring_attachment" {
  count      = var.enable_detailed_monitoring ? 1 : 0
  role       = aws_iam_role.lambda_powertag_role.name
  policy_arn = aws_iam_policy.lambda_enhanced_monitoring[0].arn
}
