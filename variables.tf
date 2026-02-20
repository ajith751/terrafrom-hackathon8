variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project identifier"
  type        = string
  default     = "healthcare-microservices"
}

variable "services" {
  description = "Map of microservices. API Gateway routes defined in openapi.yaml"
  type = map(object({
    ecr_name    = string
    image_uri   = optional(string)
    timeout     = optional(number, 30)
    memory_size = optional(number, 256)
  }))
}
