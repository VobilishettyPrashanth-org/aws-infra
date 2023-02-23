
# Create a VPC
resource "aws_vpc" "webapp_vpc" {
  cidr_block = var.cidr_name
  tags = {
    Name = var.vpc_tag_name
  }
}
# Create a IG
resource "aws_internet_gateway" "webapp_igw" {
  vpc_id = aws_vpc.webapp_vpc.id
}

data "aws_availability_zones" "available" {
  state = "available"
}
output "availability_zones" {
  value = data.aws_availability_zones.available.names
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.webapp_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.webapp_igw.id
  }
  tags = {
    Name = "public_route_table-${aws_vpc.webapp_vpc.id}"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.webapp_vpc.id
  tags = {
    Name = "private_route_table-${aws_vpc.webapp_vpc.id}"
  }
}


# resource "aws_route" "public_rt_internet_gateway" {
#   route_table_id = aws_route_table.public_rt.id
#   cidr_block = "0.0.0.0/0"
#   gateway_id = aws_internet_gateway.webapp_igw.id
# }


resource "aws_subnet" "public_subnet" {
  count                   = local.no_of_subnets
  cidr_block              = cidrsubnet(aws_vpc.webapp_vpc.cidr_block, 8, count.index)
  vpc_id                  = aws_vpc.webapp_vpc.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "public_subnet-${aws_vpc.webapp_vpc.id}-${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnet" {
  count             = local.no_of_subnets
  cidr_block        = cidrsubnet(aws_vpc.webapp_vpc.cidr_block, 8, (count.index + local.no_of_subnets))
  vpc_id            = aws_vpc.webapp_vpc.id
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "private_subnet-${aws_vpc.webapp_vpc.id}-${count.index + 1}"
  }
}

locals {
  no_of_subnets      = min(var.aws_subnet_count, length(data.aws_availability_zones.available.names))
  public_subnet_ids  = aws_subnet.public_subnet.*.id
  private_subnet_ids = aws_subnet.private_subnet.*.id
  timestamp          = formatdate("YYYY-MM-DDTHH-MM-SS", timestamp())
}

resource "aws_route_table_association" "public_subnet_association" {
  count          = length(local.public_subnet_ids)
  subnet_id      = local.public_subnet_ids[count.index]
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_subnet_association" {
  count          = length(local.private_subnet_ids)
  subnet_id      = local.private_subnet_ids[count.index]
  route_table_id = aws_route_table.private_rt.id
}


# Define the security group resource
resource "aws_security_group" "ec2-sg" {
  name_prefix = "ec2-sg"              # Set the name prefix for the security group
  vpc_id      = aws_vpc.webapp_vpc.id # Set the ID of the VPC to create the security group in

  # Define inbound rules
  ingress {
    from_port   = 22 # Allow SSH traffic
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip] # Allow traffic from all IP addresses
  }

  ingress {
    from_port   = 443 # Allow SSH traffic
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow traffic from all IP addresses
  }

  ingress {
    from_port   = 80 # Allow HTTP traffic
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow traffic from all IP addresses
  }
  ingress {
    from_port   = 5080 # Allow HTTP traffic
    to_port     = 5080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow traffic from all IP addresses
  }

  # Define outbound rules
  # egress {
  #   from_port   = 0 # Allow all outbound traffic
  #   to_port     = 0
  #   protocol    = "-1"
  #   cidr_blocks = ["0.0.0.0/0"] # Allow traffic to all IP addresses
  # }

  tags = {
    Name = "ec2-sg-${timestamp()}" # Set the name tag for the security group
  }
}
resource "aws_instance" "webapp_instance" {
  ami                    = var.my_ami                     # Set the ID of the Amazon Machine Image to use
  instance_type          = "t2.micro"                     # Set the instance type
  key_name               = "ec2"                          # Set the key pair to use for SSH access
  vpc_security_group_ids = [aws_security_group.ec2-sg.id] # Set the security group to attach to the instance
  subnet_id              = local.public_subnet_ids[0]     # Set the ID of the subnet to launch the instance in
  # Enable protection against accidental termination
  disable_api_termination = false
  # Set the root volume size and type
  root_block_device {
    volume_size           = 50    # Replace with your preferred root volume size (in GB)
    volume_type           = "gp2" # Replace with your preferred root volume type (e.g. "gp2", "io1", etc.)
    delete_on_termination = true
  }
  # Allocate a public IPv4 address
  # associate_public_ip_address = true
  tags = {
    Name = "webapp-instance-${timestamp()}" # Set the name tag for the instance
  }
}
