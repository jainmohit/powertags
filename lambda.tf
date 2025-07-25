# CloudWatch Log Groups for Lambda functions
resource "aws_cloudwatch_log_group" "start_lambda_logs" {
  name              = "/aws/lambda/${var.name_prefix}-start-instances"
  retention_in_days = var.lambda_log_retention_days

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-start-lambda-logs"
    Type = "PowerTag-Logs"
  })
}

resource "aws_cloudwatch_log_group" "stop_lambda_logs" {
  name              = "/aws/lambda/${var.name_prefix}-stop-instances"
  retention_in_days = var.lambda_log_retention_days

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-stop-lambda-logs"
    Type = "PowerTag-Logs"
  })
}

# Create ZIP file for Lambda deployment package
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"
  source {
    content = templatefile("${path.module}/lambda_function.py", {
      aws_region = data.aws_region.current.name
    })
    filename = "lambda_function.py"
  }
}

# Lambda function for starting instances
resource "aws_lambda_function" "start_instances" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.name_prefix}-start-instances"
  role            = aws_iam_role.lambda_powertag_role.arn
  handler         = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime         = var.lambda_runtime
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size

  environment {
    variables = {
      ACTION = "start"
      REGION = data.aws_region.current.name
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_powertag_policy_attachment,
    aws_cloudwatch_log_group.start_lambda_logs,
  ]

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-start-lambda"
    Type = "PowerTag-Lambda"
    Action = "Start"
  })
}

# Lambda function for stopping instances
resource "aws_lambda_function" "stop_instances" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.name_prefix}-stop-instances"
  role            = aws_iam_role.lambda_powertag_role.arn
  handler         = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime         = var.lambda_runtime
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size

  environment {
    variables = {
      ACTION = "stop"
      REGION = data.aws_region.current.name
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_powertag_policy_attachment,
    aws_cloudwatch_log_group.stop_lambda_logs,
  ]

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-stop-lambda"
    Type = "PowerTag-Lambda"
    Action = "Stop"
  })
}
