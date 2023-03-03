
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
resource "aws_security_group" "app_sg" {
  name_prefix = "application"         # Set the name prefix for the security group
  vpc_id      = aws_vpc.webapp_vpc.id # Set the ID of the VPC to create the security group in

  # Define inbound rules
  ingress {
    from_port   = 22 # Allow SSH traffic
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow traffic from all IP addresses
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
    from_port   = 5050 # Allow HTTP traffic
    to_port     = 5050
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow traffic from all IP addresses
  }


  # egress {
  #   # description = "Allow Postgres traffic fromy the application security group"
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }
  # egress {
  #   # description = "Allow Postgres traffic fromy the application security group"
  #   from_port   = 0
  #   to_port     = 0
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }
   egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-sg-${timestamp()}" # Set the name tag for the security group
  }
}
# Database security group
resource "aws_security_group" "db_sg" {
  name        = "database"
  description = "Security group for RDS instance for database"
  vpc_id      = aws_vpc.webapp_vpc.id
  ingress {
    protocol        = "tcp"
    from_port       = 3306
    to_port         = 3306
    security_groups = [aws_security_group.app_sg.id]
  }

  # egress {
  #   from_port   = 0
  #   to_port     = 0
  #   protocol    = "-1"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }
  tags = {
    "Name" = "database-sg-${timestamp()}"
  }
}

# # Add an inbound rule to the RDS security group to allow traffic from the EC2 security group
# resource "aws_security_group_rule" "rds_ingress" {
#   type                     = "ingress"
#   from_port                = 3306
#   to_port                  = 3306
#   protocol                 = "tcp"
#   security_group_id        = aws_security_group.db_sg.id
#   source_security_group_id = aws_security_group.app_sg.id
# }

# # Add an outbound rule to the RDS security group to allow traffic from the EC2 security group
# resource "aws_security_group_rule" "rds_egress" {
#   type                     = "egress"
#   from_port                = 3306
#   to_port                  = 3306
#   protocol                 = "tcp"
#   security_group_id        = aws_security_group.db_sg.id
#   source_security_group_id = aws_security_group.app_sg.id
# }

# Add an inbound rule to the EC2 security group to allow traffic to the RDS security group
# resource "aws_security_group_rule" "ec2_ingress" {
#   type                     = "ingress"
#   from_port                = 3306
#   to_port                  = 3306
#   protocol                 = "tcp"
#   security_group_id        = aws_security_group.app_sg.id
#   source_security_group_id = aws_security_group.db_sg.id
# }
resource "aws_instance" "webapp_instance" {
  ami                    = var.my_ami                     # Set the ID of the Amazon Machine Image to use
  instance_type          = "t2.micro"                     # Set the instance type
  key_name               = "aws_key"                          # Set the key pair to use for SSH access
  vpc_security_group_ids = [aws_security_group.app_sg.id] # Set the security group to attach to the instance
  subnet_id              = local.public_subnet_ids[0]    # Set the ID of the subnet to launch the instance in
  # Enable protection against accidental termination
  disable_api_termination = false
  # Set the root volume size and type
  root_block_device {
    volume_size           = 20    # Replace with your preferred root volume size (in GB)
    volume_type           = "gp2" # Replace with your preferred root volume type (e.g. "gp2", "io1", etc.)
    delete_on_termination = true
  }
  depends_on           = [aws_db_instance.rds_instance]
  iam_instance_profile = aws_iam_instance_profile.iam_profile.name
  user_data            = <<EOF
#!/bin/bash
cd /home/ec2-user || return
touch application.properties
sudo chown ec2-user:ec2-user application.properties
sudo chmod 775 application.properties
echo "aws.region=${var.aws_region}" >> application.properties
echo "aws.s3.bucketName=${aws_s3_bucket.s3b.bucket}" >> application.properties
echo "server.port=5050" >> application.properties
echo "spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver" >> application.properties
echo "spring.datasource.url=jdbc:mysql://${aws_db_instance.rds_instance.endpoint}/${aws_db_instance.rds_instance.db_name}?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC" >> application.properties
echo "spring.datasource.username=${aws_db_instance.rds_instance.username}" >> application.properties
echo "spring.datasource.password=${aws_db_instance.rds_instance.password}" >> application.properties
echo "spring.jpa.properties.hibernate.show_sql=true" >> application.properties
echo "spring.jpa.properties.hibernate.use_sql_comments=true" >> application.properties
echo "spring.jpa.properties.hibernate.format_sql=true" >> application.properties
echo "logging.level.org.hibernate.type=trace" >> application.properties
echo "#spring.jpa.properties.hibernate.dialect = org.hibernate.dialect.MySQL5InnoDBDialect" >> application.properties
echo "spring.jpa.hibernate.ddl-auto=update" >> application.properties
sudo chmod 770 /home/ec2-user/webapp-0.0.1-SNAPSHOT.jar
sudo cp /tmp/webservice.service /etc/systemd/system
sudo chmod 770 /etc/systemd/system/webservice.service
sudo systemctl start webservice.service
sudo systemctl enable webservice.service
sudo systemctl daemon-reload
sudo systemctl start webservice.service
sudo systemctl enable webservice.service
  EOF

  tags = {
    Name = "webapp-instance-${timestamp()}" # Set the name tag for the instance
  }
}

resource "random_pet" "rg" {
  keepers = {
    # Generate a new pet name each time we switch to a new profile
    random_name= "webapp"
  }
}
// Create s3 bucket
resource "aws_s3_bucket" "s3b" {
  bucket        = random_pet.rg.id
  force_destroy = true
  tags = {
    Name = "${random_pet.rg.id}"
  }
}
resource "aws_s3_bucket_acl" "s3b_acl" {
  bucket = aws_s3_bucket.s3b.id
  acl    = "private"
}
resource "aws_s3_bucket_lifecycle_configuration" "s3b_lifecycle" {
  bucket = aws_s3_bucket.s3b.id
  rule {
    id     = "rule-1"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3b_encryption" {
  bucket = aws_s3_bucket.s3b.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }

}

resource "aws_s3_bucket_public_access_block" "s3_block" {
  bucket              = aws_s3_bucket.s3b.id
  block_public_acls   = true
  block_public_policy = true
}
resource "aws_iam_policy" "policy" {
  name        = "WebAppS3"
  description = "policy for s3"

  policy = jsonencode({
    "Version" : "2012-10-17"
    "Statement" : [
      {
        "Action" : ["s3:DeleteObject", "s3:PutObject", "s3:GetObject", "s3:ListAllMyBuckets", "s3:ListBucket"]
        "Effect" : "Allow"
        "Resource" : ["arn:aws:s3:::${aws_s3_bucket.s3b.bucket}",
        "arn:aws:s3:::${aws_s3_bucket.s3b.bucket}/*"]
      }
    ]
  })
}

resource "aws_iam_role" "ec2-role" {
  name = "EC2-CSYE6225"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "web-app-s3-attach" {
  name       = "gh-upload-to-s3-attachment"
  roles      = [aws_iam_role.ec2-role.name]
  policy_arn = aws_iam_policy.policy.arn
}



resource "aws_iam_instance_profile" "iam_profile" {
  name = "iam_profile"
  role = aws_iam_role.ec2-role.name
}

#s3 bucket
# resource "aws_s3_bucket" "s3_bucket" {
#   lifecycle_rule {
#     id      = "StorageTransitionRule"
#     enabled = true
#     transition {
#       days          = 30
#       storage_class = "STANDARD_IA"
#     }
#   }
#   server_side_encryption_configuration {
#     rule {
#       apply_server_side_encryption_by_default {
#         sse_algorithm = "AES256"
#       }
#     }
#   }

#   tags = {
#     "Name" = "s3_bucket-${timestamp()}"
#   }
# }

#iam role for ec2
# resource "aws_iam_role" "ec2_role" {
#   description        = "Policy for EC2 instance"
#   name               = "tf-ec2-role"
#   assume_role_policy = <<EOF
# {
#   "Version": "2012-10-17", 
#   "Statement": [
#     {
#       "Action": "sts:AssumeRole", 
#       "Effect": "Allow", 
#       "Principal": {
#         "Service": "ec2.amazonaws.com"
#       }
#     }
#   ]
# }
# EOF
#   tags = {
#     "Name" = "ec2-iam-role"
#   }
# }

# #policy document
# data "aws_iam_policy_document" "policy_document" {
#   version = "2012-10-17"
#   statement {
#     actions = [
#       "s3:PutObject",
#       "s3:GetObject",
#       "s3:DeleteObject",
#       "s3:ListBucket"
#     ]
#     resources = ["arn:aws:s3:::${aws_s3_bucket.s3_bucket.arn}",
#     "arn:aws:s3:::${aws_s3_bucket.s3_bucket.arn}/*"]
#   }
#   depends_on = [aws_s3_bucket.s3_bucket]
# }

# #iam policy for role
# resource "aws_iam_role_policy" "s3_policy" {
#   name       = "tf-s3-policy"
#   role       = aws_iam_role.ec2_role.id
#   policy     = data.aws_iam_policy_document.policy_document.json
#   depends_on = [aws_s3_bucket.s3_bucket]
# }

resource "aws_db_subnet_group" "db_subnet_group" {
  description = "Private Subnet group for RDS"
  subnet_ids  = ([local.private_subnet_ids[0], local.private_subnet_ids[1], local.private_subnet_ids[2]])
  tags = {
    "Name" = "db-subnet-group"
  }
}
# RDS Parameter Group
resource "aws_db_parameter_group" "rds_parameter_group" {
  name_prefix = "rds-parameter-group"
  family      = "mysql5.7"
  description = "RDS DB parameter group for MySQL 8.0"
  parameter {
    name  = "character_set_client"
    value = "utf8"
  }
  parameter {
    name  = "character_set_server"
    value = "utf8"
  }
}
resource "aws_db_instance" "rds_instance" {
  allocated_storage      = var.db_storage_size
  identifier             = "app-rds-db-1"
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  instance_class         = var.db_instance_class
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  //multi_az               = false
  name                = var.db_name
  username            = var.db_username
  password            = var.db_password
  publicly_accessible = var.db_public_access
  # publicly_accessible  = true
  multi_az             = var.db_multiaz
  parameter_group_name = aws_db_parameter_group.rds_parameter_group.name
  skip_final_snapshot  = true
  tags = {
    "Name" = "rds-${timestamp()}"
  }
}


# #iam instance profile for ec2
# resource "aws_iam_instance_profile" "ec2_profile" {
#   role = aws_iam_role.ec2_role.name
# }
