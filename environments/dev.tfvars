environment = "dev"
aws_region  = "us-east-1"

services = {
  patient = {
    ecr_name = "patient-service"
  }

  appointment = {
    ecr_name = "appointment-service"
  }
}
