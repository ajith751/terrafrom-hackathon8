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
  tags            = local.common_tags
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

  # Resource policy: allow API Gateway to invoke Lambda (Lambda → Configuration → Permissions)
  allow_api_gateway_invoke  = true
  api_gateway_execution_arn = aws_apigatewayv2_api.main.execution_arn

  tags = local.common_tags
}

# API Gateway HTTP API - explicit integrations and routes
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-api-${var.environment}"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH", "HEAD"]
    allow_headers = ["*"]
  }

  tags = local.common_tags
}

# Lambda integrations - explicitly attach Lambdas to API Gateway
resource "aws_apigatewayv2_integration" "patient" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = module.lambda["patient"].invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "appointment" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = module.lambda["appointment"].invoke_arn
  payload_format_version = "2.0"
}

# Routes - Patient service
resource "aws_apigatewayv2_route" "patient_root" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.patient.id}"
}

resource "aws_apigatewayv2_route" "patient_health" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.patient.id}"
}

resource "aws_apigatewayv2_route" "patient_list" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /patients"
  target    = "integrations/${aws_apigatewayv2_integration.patient.id}"
}

resource "aws_apigatewayv2_route" "patient_create" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /patients"
  target    = "integrations/${aws_apigatewayv2_integration.patient.id}"
}

resource "aws_apigatewayv2_route" "patient_get" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /patients/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.patient.id}"
}

# Routes - Appointment service
resource "aws_apigatewayv2_route" "appointment_list" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /appointments"
  target    = "integrations/${aws_apigatewayv2_integration.appointment.id}"
}

resource "aws_apigatewayv2_route" "appointment_create" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /appointments"
  target    = "integrations/${aws_apigatewayv2_integration.appointment.id}"
}

resource "aws_apigatewayv2_route" "appointment_get" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /appointments/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.appointment.id}"
}

resource "aws_apigatewayv2_route" "appointment_by_patient" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /appointments/patient/{patientId}"
  target    = "integrations/${aws_apigatewayv2_integration.appointment.id}"
}

# Explicit deployment - ensures API with all routes/integrations is deployed
resource "aws_apigatewayv2_deployment" "main" {
  api_id = aws_apigatewayv2_api.main.id

  triggers = {
    redeployment = sha1(join(",", [
      aws_apigatewayv2_integration.patient.id,
      aws_apigatewayv2_integration.appointment.id,
      aws_apigatewayv2_route.patient_root.id,
      aws_apigatewayv2_route.patient_health.id,
      aws_apigatewayv2_route.patient_list.id,
      aws_apigatewayv2_route.patient_create.id,
      aws_apigatewayv2_route.patient_get.id,
      aws_apigatewayv2_route.appointment_list.id,
      aws_apigatewayv2_route.appointment_create.id,
      aws_apigatewayv2_route.appointment_get.id,
      aws_apigatewayv2_route.appointment_by_patient.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Stage - $default stage, linked to deployment
resource "aws_apigatewayv2_stage" "default" {
  api_id        = aws_apigatewayv2_api.main.id
  deployment_id = aws_apigatewayv2_deployment.main.id
  name          = "$default"

  tags = local.common_tags
}

# Lambda resource policy (API Gateway invoke) is in modules/lambda-container
# Shows in Lambda Console: Configuration → Permissions → Resource-based policy statements
