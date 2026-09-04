terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }

  backend "s3" {
    bucket         = "pgh-banking-tfstate-dev"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "pgh-banking-tflocks-dev"
    encrypt        = true
  }
}
module "aws_banking_vpc" {
  source      = "../../modules/aws_vpc"
  environment = var.environment
  vpc_cidr    = "10.0.0.0/16"
}
