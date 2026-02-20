output "ecr_repository_urls" {
  description = "ECR repository URLs per service"
  value       = { for k, v in module.ecr : k => v.repository_url }
}

output "lambda_function_names" {
  description = "Lambda function names per service"
  value       = { for k, v in module.lambda : k => v.function_name }
}

output "api_base_url" {
  description = "Base URL for API"
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "api_id" {
  description = "API Gateway ID"
  value       = aws_apigatewayv2_api.main.id
}
