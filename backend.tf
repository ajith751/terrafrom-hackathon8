# Remote state - S3 + DynamoDB lock
# Local: terraform init -backend-config=backend.hcl
# CI: Uses TF_BACKEND_* secrets to create backend config

terraform {
  backend "s3" {
    # Configured via backend.hcl (local) or GitHub Actions (CI)
  }
}
