variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "image_uri" {
  description = "ECR image URI for the Lambda container"
  type        = string
}

variable "timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "memory_size" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 256
}

variable "environment_variables" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "allow_api_gateway_invoke" {
  description = "If set, adds resource policy allowing API Gateway to invoke this Lambda"
  type        = bool
  default     = false
}

variable "api_gateway_execution_arn" {
  description = "API Gateway execution ARN for Lambda permission (required when allow_api_gateway_invoke=true)"
  type        = string
  default     = ""
}
