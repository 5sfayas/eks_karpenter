provider "aws" {
  region = "us-east-1"
  profile = "fayas" # give profile if configured
}

terraform {
  required_version = "~> 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.6"
    }
  }
}

terraform {
  backend "s3" {
    bucket = "my-test-bucket-new" # enable this if environment prod
    #bucket = "hupe-infrastructure" # enable this if environment stage
    key    = "eks/us-east-1/tfstate"
    region = "us-east-1" #var.region
  }
}