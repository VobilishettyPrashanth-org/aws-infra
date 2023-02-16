terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

module "web_app" {
  source = "../../web_app_module"

  # Input Variables
  cidr_name    = var.cidr_name
  vpc_tag_name = var.vpc_tag_name
  aws_region      = var.aws_region

}

