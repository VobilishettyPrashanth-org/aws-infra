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
  source = "../../web-app-module"

  # Input Variables
  cidr_name        = var.cidr_name
  vpc_tag_name     = var.vpc_tag_name
  aws_region       = var.aws_region
  aws_subnet_count = var.aws_subnet_count
  #my_ip            = var.my_ip
  my_ami            = var.my_ami
  db_storage_size   = var.db_storage_size
  db_instance_class = var.db_instance_class
  db_engine         = var.db_engine
  db_engine_version = var.db_engine_version
  db_name           = var.db_name
  db_username       = var.db_username
  db_password       = var.db_password
  db_public_access  = var.db_public_access
  db_multiaz        = var.db_multiaz

}

