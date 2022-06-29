variable "prefix" {
  default = "apigw-ex2-"
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
  prefix = var.prefix # just as macro
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
  name              = "/aws/lambda/${aws_lambda_function.hello.function_name}"
  retention_in_days = var.log_retention_in_days
}

resource "null_resource" "hello" {
  provisioner "local-exec" {
    command = "${var.python} -m pip install -U -r ./src/${var.lambda_name}/requirements.txt -t ./src/${var.lambda_name}/"
  }
  triggers = {
    dependencies_versions = filemd5("./src/${var.lambda_name}/requirements.txt")
    source_versions       = filemd5("./src/${var.lambda_name}/app.py")
  }
}

data "archive_file" "hello" {
  depends_on  = [null_resource.hello]
  excludes    = ["__pycache__", "venv"]
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

data "template_file" "api" {
  template = file("./hello_api.yml")
  vars = {
    title              = "${local.prefix}apigw1"
    aws_region_name    = var.aws_region
    stage_name         = var.stage_name
    hello_function_arn = aws_lambda_function.hello.arn
  }
}

resource "aws_api_gateway_rest_api" "default" {
  body = data.template_file.api.rendered
  name = "${local.prefix}apigw1"
}

resource "aws_api_gateway_deployment" "default" {
  rest_api_id = aws_api_gateway_rest_api.default.id
  stage_name  = var.stage_name
  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.default.body))
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lambda_permission" "hello" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
  function_name = aws_lambda_function.hello.function_name
  source_arn    = "${aws_api_gateway_rest_api.default.execution_arn}/*/*"
}

output "hello_url" {
  value = "${aws_api_gateway_deployment.default.invoke_url}/hello"
}
output "api_body" {
  value = aws_api_gateway_rest_api.default.body
}
