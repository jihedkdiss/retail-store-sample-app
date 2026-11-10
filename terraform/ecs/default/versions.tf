terraform {
  required_version = ">= 1.10.0"

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
      app        = "retail-store"
      env        = "dev"
      owner      = "jihed"
      managed-by = "terraform"
    }
  }
}
