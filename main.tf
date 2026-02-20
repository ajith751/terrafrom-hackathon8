terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# ECR + Lambda per service (modules)
module "ecr" {
  source   = "./modules/ecr"
  for_each = var.services

  repository_name = "${var.project_name}-${each.value.ecr_name}"
  tags           = local.common_tags
}

module "lambda" {
  source   = "./modules/lambda-container"
  for_each = var.services

  function_name = "${var.project_name}-${replace(each.key, "_", "-")}-${var.environment}"
  image_uri     = coalesce(each.value.image_uri, "${module.ecr[each.key].repository_url}:latest")
  timeout       = each.value.timeout
  memory_size   = each.value.memory_size

  environment_variables = {
    NODE_ENV = var.environment
  }

  tags = local.common_tags
}

# API Gateway - created from openapi.yaml (single source of truth)
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-api-${var.environment}"
  protocol_type = "HTTP"
  body = templatefile("${path.module}/openapi.yaml", {
    patient_lambda_invoke_arn    = module.lambda["patient"].invoke_arn
    appointment_lambda_invoke_arn = module.lambda["appointment"].invoke_arn
  })

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS", "ANY"]
    allow_headers = ["*"]
  }

  tags = local.common_tags
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  tags = local.common_tags
}

resource "aws_lambda_permission" "patient_api" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda["patient"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "appointment_api" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda["appointment"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
