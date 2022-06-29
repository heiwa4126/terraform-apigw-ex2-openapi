variable "prefix" {
  default = "apigw-ex1-"
}
variable "aws_region" {
  default = "ap-northeast-3"
}
variable "stage_name" {
  default = "dev"
}
variable "lambda_name" {
  default = "hello"
}
variable "author_mail" {
  default = "foo@example.com"
}
variable "python" {
  default = "python3.9"
}
variable "log_retention_in_days" {
  default = 7
}
locals {
  prefix = var.prefix  # just as macro
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      mail        = var.author_mail
      provided_by = "Terraform"
    }
  }
}

resource "aws_iam_role" "hello" {
  path               = "/lambda/"
  name               = "${local.prefix}${var.lambda_name}"
  assume_role_policy = data.aws_iam_policy_document.lambda_default.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]
}

resource "aws_cloudwatch_log_group" "hello" {
  name              = "/aws/lambda/${var.lambda_name}"
  retention_in_days = var.log_retention_in_days
}

data "archive_file" "hello" {
  type        = "zip"
  source_dir  = "./src/${var.lambda_name}"
  output_path = "./tmp/${var.lambda_name}.zip"
}

resource "aws_lambda_function" "hello" {
  function_name = "${local.prefix}${var.lambda_name}"

  filename         = data.archive_file.hello.output_path
  source_code_hash = data.archive_file.hello.output_base64sha256

  handler = "app.lambda_handler"
  runtime = var.python
  role    = aws_iam_role.hello.arn
}

data "aws_iam_policy_document" "lambda_default" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_api_gateway_rest_api" "default" {
  name = "${local.prefix}apigw1"
}

resource "aws_api_gateway_resource" "hello" {
  rest_api_id = aws_api_gateway_rest_api.default.id
  parent_id   = aws_api_gateway_rest_api.default.root_resource_id
  path_part   = "hello"
}

resource "aws_api_gateway_method" "hello" {
  rest_api_id   = aws_api_gateway_rest_api.default.id
  resource_id   = aws_api_gateway_resource.hello.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "hello" {
  rest_api_id = aws_api_gateway_method.hello.rest_api_id
  resource_id = aws_api_gateway_method.hello.resource_id
  http_method = aws_api_gateway_method.hello.http_method
  uri         = aws_lambda_function.hello.invoke_arn

  type                    = "AWS_PROXY"
  integration_http_method = "POST" # これ重要
}

resource "aws_api_gateway_deployment" "default" {
  depends_on = [
    aws_api_gateway_integration.hello,
  ]

  rest_api_id = aws_api_gateway_rest_api.default.id
  stage_name  = var.stage_name

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lambda_permission" "hello" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
  function_name = aws_lambda_function.hello.function_name
  # loose
  source_arn = "${aws_api_gateway_rest_api.default.execution_arn}/*/*"
  # strict: source_arn = "${aws_api_gateway_rest_api.default.execution_arn}/*/${aws_api_gateway_method.method.http_method}${aws_api_gateway_resource.proxy.path}"
}

output "hello_url" {
  value = "${aws_api_gateway_deployment.default.invoke_url}/hello"
}
