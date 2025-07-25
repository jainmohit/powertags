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
    Type = "PowerTag-RDS-IAM"
  })
}

# IAM Policy for RDS PowerTag Operations
resource "aws_iam_policy" "lambda_powertag_policy" {
  name        = "${var.name_prefix}-lambda-powertag-policy"
  description = "IAM policy for PowerTag Lambda functions to manage RDS instances"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters",
          "rds:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "rds:StartDBInstance",
          "rds:StopDBInstance"
        ]
        Resource = "arn:aws:rds:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:db:*"
        Condition = {
          StringEquals = {
            "rds:db-tag/PowerTagEnabled" = "true"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "rds:AddTagsToResource"
        ]
        Resource = "arn:aws:rds:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:db:*"
        Condition = {
          StringEquals = {
            "rds:db-tag/PowerTagEnabled" = "true"
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
    Type = "PowerTag-RDS-IAM"
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
