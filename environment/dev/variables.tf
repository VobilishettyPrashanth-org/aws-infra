variable "cidr_name" {
  description = "Name of cidr block"
  type        = string
}
variable "vpc_tag_name" {
  description = "tag Name of Vpc"
  type        = string
}
variable "aws_profile" {
  description = "aws profile name"
  type        = string
}
variable "aws_region" {
  description = "aws region name"
  type        = string
}
variable "aws_subnet_count" {
  description = "aws subnet count"
  type        = number
}
variable "my_ip" {
  description = "my current ip address"
  type        = string
}
variable "my_ami" {
  description = "my ami"
  type        = string
}

variable "db_storage_size" {
  description = "Availability zones for subnets."
  type        = number
}

variable "db_instance_class" {
  description = "Instance class for RDS"
  type        = string
}

variable "db_engine" {
  description = "DB engine for RDS"
  type        = string
}

variable "db_engine_version" {
  description = "DB engine version for RDS"
  type        = string
}

variable "db_name" {
  description = "DB name"
  type        = string
}

variable "db_username" {
  description = "DB username"
  type        = string
}

variable "db_password" {
  description = "DB password"
  type        = string
}


variable "db_public_access" {
  description = "DB public accessibility"
  type        = bool
}

variable "db_multiaz" {
  description = "DB multi AZ"
  type        = bool
}
