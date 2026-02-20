variable "api_name" {
  description = "Name of the API Gateway"
  type        = string
}

variable "description" {
  description = "API description"
  type        = string
  default     = ""
}

variable "stage_name" {
  description = "Name of the deployment stage"
  type        = string
  default     = "$default"
}

variable "routes" {
  description = "List of routes. Each must have route_key (e.g. GET /health), integration_uri (Lambda invoke ARN), and function_name (for permission)"
  type = list(object({
    route_key       = string
    integration_uri = string
    function_name   = string
  }))
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
