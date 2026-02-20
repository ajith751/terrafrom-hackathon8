resource "aws_apigatewayv2_api" "this" {
  name          = var.api_name
  protocol_type = "HTTP"
  description   = var.description

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS", "ANY"]
    allow_headers = ["*"]
  }

  tags = var.tags
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = var.stage_name
  auto_deploy = true

  tags = var.tags
}

resource "aws_apigatewayv2_integration" "routes" {
  for_each = { for r in var.routes : "${r.route_key}" => r }

  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = each.value.integration_uri
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "routes" {
  for_each = { for r in var.routes : "${r.route_key}" => r }

  api_id    = aws_apigatewayv2_api.this.id
  route_key = each.value.route_key
  target    = "integrations/${aws_apigatewayv2_integration.routes[each.key].id}"
}

resource "aws_lambda_permission" "api_invoke" {
  for_each = toset([for r in var.routes : r.function_name if r.function_name != ""])

  statement_id  = "AllowAPIGatewayInvoke-${replace(each.value, "/[^a-zA-Z0-9-]/", "-")}"
  action        = "lambda:InvokeFunction"
  function_name = each.value
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}
