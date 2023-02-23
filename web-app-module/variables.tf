variable "cidr_name" {
  description = "Name of cidr block"
  type        = string
}
variable "vpc_tag_name" {
  description = "tag Name of Vpc"
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
