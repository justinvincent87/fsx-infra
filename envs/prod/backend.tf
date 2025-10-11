terraform {
  backend "s3" {
    bucket  = "718277287949-us-east-1-prod"
    key     = "infra/prod/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
