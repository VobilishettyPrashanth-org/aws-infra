
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

  # ingress {
  #   from_port   = 80 # Allow HTTP traffic
  #   to_port     = 80
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"] # Allow traffic from all IP addresses
  # }
  ingress {
    from_port = 5050 # Allow HTTP traffic
    to_port   = 5050
    protocol  = "tcp"
    # cidr_blocks = [aws_security_group.lb_sg.id] # Allow traffic from all IP addresses
    security_groups = [aws_security_group.lb_sg.id]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
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
  tags = {
    "Name" = "database-sg-${timestamp()}"
  }
}

resource "aws_security_group" "lb_sg" {
  name        = "load balancer"
  description = "Security group for load balancer"
  vpc_id      = aws_vpc.webapp_vpc.id

  # ingress {
  #   from_port   = 80 # Allow HTTP traffic
  #   to_port     = 80
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"] # Allow traffic from all IP addresses
  # }
  ingress {
    from_port   = 443 # Allow SSH traffic
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow traffic from all IP addresses
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    "Name" = "lb-sg-${timestamp()}"
  }
}
data "template_file" "user_data" {
  template = <<EOF
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
echo "#spring.jpa.properties.hibernate.dialect = org.hibernate.dialect.MySQL5InnoDBDialect" >> application.properties
echo "spring.jpa.hibernate.ddl-auto=update" >> application.properties
echo "logging.file.path=/home/ec2-user" >> application.properties
echo "logging.file.name=/home/ec2-user/csye6225.log" >> application.properties
echo "publish.metrics=true" >> application.properties
echo "metrics.server.hostname=localhost" >> application.properties
echo "metrics.server.port=8125" >> application.properties
sudo chmod 770 /home/ec2-user/webapp-0.0.1-SNAPSHOT.jar
sudo cp /tmp/webservice.service /etc/systemd/system
sudo cp /tmp/cloudwatch-config.json /opt/cloudwatch-config.json
sudo chmod 770 /opt/cloudwatch-config.json
sudo chmod 770 /etc/systemd/system/webservice.service
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/cloudwatch-config.json \
    -s
sudo systemctl daemon-reload
sudo systemctl start webservice.service
sudo systemctl enable webservice.service
  EOF
}


#resource "aws_kms_key" "webapp-kms-ec2" {
#   alias_name = "webapp-kms-ec2"
#  description              = "EC2 Encryption key"
#  key_usage                = "ENCRYPT_DECRYPT"
#  customer_master_key_spec = "SYMMETRIC_DEFAULT"
#  deletion_window_in_days  = 7
#  policy = jsonencode({
#    "Id" : "key-consolepolicy-3",
#    "Version" : "2012-10-17",
#    "Statement" : [
#      {
#        "Sid" : "Enable IAM User Permissions",
#        "Effect" : "Allow",
#        "Principal" : {
#          "AWS" : "arn:aws:iam::${var.aws_account_id}:root"
#        },
#        "Action" : "kms:*",
#        "Resource" : "*"
#      },
#      {
#        "Sid" : "Allow access for Key Administrators",
#        "Effect" : "Allow",
#        "Principal" : {
#          "AWS" : ["arn:aws:iam::${var.aws_account_id}:role/aws-service-role/elasticloadbalancing.amazonaws.com/AWSServiceRoleForElasticLoadBalancing",
#            "arn:aws:iam::${var.aws_account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
#          ]
#        },
#        "Action" : [
#          "kms:Create*",
#          "kms:Describe*",
#          "kms:Enable*",
#          "kms:List*",
#          "kms:Put*",
#          "kms:Update*",
#          "kms:Revoke*",
#          "kms:Disable*",
#          "kms:Get*",
#          "kms:Delete*",
#          "kms:TagResource",
#          "kms:UntagResource",
#          "kms:ScheduleKeyDeletion",
#          "kms:CancelKeyDeletion"
#        ],
#        "Resource" : "*"
#      },
#      {
#        "Sid" : "Allow use of the key",
#        "Effect" : "Allow",
#        "Principal" : {
#          "AWS" : [
#            "arn:aws:iam::${var.aws_account_id}:role/aws-service-role/elasticloadbalancing.amazonaws.com/AWSServiceRoleForElasticLoadBalancing",
#            "arn:aws:iam::${var.aws_account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
#          ]
#        },
#        "Action" : [
#          "kms:Encrypt",
#          "kms:Decrypt",
#          "kms:ReEncrypt*",
#          "kms:GenerateDataKey*",
#          "kms:DescribeKey"
#        ],
#        "Resource" : "*"
#      },
#      {
#        "Sid" : "Allow attachment of persistent resources",
#        "Effect" : "Allow",
#        "Principal" : {
#          "AWS" : ["arn:aws:iam::${var.aws_account_id}:role/aws-service-role/elasticloadbalancing.amazonaws.com/AWSServiceRoleForElasticLoadBalancing",
#            "arn:aws:iam::${var.aws_account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
#          ]
#        },
#        "Action" : [
#          "kms:CreateGrant",
#          "kms:ListGrants",
#          "kms:RevokeGrant"
#        ],
#        "Resource" : "*",
#        "Condition" : {
#          "Bool" : {
#            "kms:GrantIsForAWSResource" : "true"
#          }
#        }
#      }
#    ]
#  })
#}
resource "aws_kms_key" "webapp-kms-rds" {
  # alias_name = "webapp-kms-rds"
  description              = "RDS Encryption key"
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  deletion_window_in_days  = 7
  policy = jsonencode({
    "Id": "key-consolepolicy-3",
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "Enable IAM User Permissions",
        "Effect": "Allow",
        "Principal": {
          "AWS": "arn:aws:iam::${var.aws_account_id}:root"
        },
        "Action": "kms:*",
        "Resource": "*"
      },
      {
        "Sid": "Allow access for Key Administrators",
        "Effect": "Allow",
        "Principal": {
          "AWS": "arn:aws:iam::${var.aws_account_id}:role/aws-service-role/rds.amazonaws.com/AWSServiceRoleForRDS"
        },
        "Action": [
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion"
        ],
        "Resource": "*"
      },
      {
        "Sid": "Allow use of the key",
        "Effect": "Allow",
        "Principal": {
          "AWS": "arn:aws:iam::${var.aws_account_id}:role/aws-service-role/rds.amazonaws.com/AWSServiceRoleForRDS"
        },
        "Action": [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        "Resource": "*"
      },
      {
        "Sid": "Allow attachment of persistent resources",
        "Effect": "Allow",
        "Principal": {
          "AWS": "arn:aws:iam::${var.aws_account_id}:role/aws-service-role/rds.amazonaws.com/AWSServiceRoleForRDS"
        },
        "Action": [
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant"
        ],
        "Resource": "*",
        "Condition": {
          "Bool": {
            "kms:GrantIsForAWSResource": "true"
          }
        }
      }
    ]
  })
}


# data "aws_kms_key" "webapp-ec2-kms" {
#   key_id = "7bbeca5d-e211-479a-a62b-5f1a9a83b954"
# }

# data "aws_kms_key" "webapp-rds-kms" {
#   key_id = "8652cc85-93c5-49e4-ba87-c33dcb76d39b"
# }
resource "aws_launch_template" "lt" {
  name                   = "asg_launch_config"
  image_id               = var.my_ami
  instance_type          = "t2.micro"
  key_name               = "aws_key"
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  user_data              = base64encode(data.template_file.user_data.rendered)
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 30
      volume_type           = "gp2"
      delete_on_termination = true
#      encrypted             = true
#      kms_key_id            = aws_kms_key.webapp-kms-ec2.arn
      # kms_key_id            = data.aws_kms_key.webapp-ec2-kms.arn
    }
  }
  # network_interfaces {
  #   associate_public_ip_address = true
  #   security_groups             = [aws_security_group.app_sg.id]
  # }
  iam_instance_profile {
    name = aws_iam_instance_profile.iam_profile.name
  }
}

resource "aws_autoscaling_group" "asg" {
  name = "csye6225-asg-spring2023"
  tag {
    key                 = "webApp"
    value               = "web app"
    propagate_at_launch = true
  }
  vpc_zone_identifier = [local.public_subnet_ids[0], local.public_subnet_ids[1]]
  min_size            = 1
  max_size            = 3
  desired_capacity    = 1
  default_cooldown    = 60
  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  target_group_arns = [
    aws_lb_target_group.alb_tg.arn
  ]

}

# resource "aws_autoscaling_policy" "asg_cpu_scale_up_policy" {
#   name                   = "csye6225-asg-cpu_scale_up"
#   autoscaling_group_name = aws_autoscaling_group.asg.name
#   adjustment_type        = "ChangeInCapacity"
#   policy_type            = "TargetTrackingScaling"
#   # scaling_adjustment     = 1
#   # CPU Utilization is above 20%
#   target_tracking_configuration {
#     predefined_metric_specification {
#       predefined_metric_type = "ASGAverageCPUUtilization"
#     }
#     target_value = 5.0
#   }
# }

#Autoscaling policies - Scale up
resource "aws_autoscaling_policy" "scale_up_policy" {
  name                   = "autoscaling_up_policy"
  policy_type            = "SimpleScaling"
  scaling_adjustment     = "1"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
}

#Autoscaling policies - Scale down
resource "aws_autoscaling_policy" "scale_down_policy" {
  name                   = "autoscaling_down_policy"
  policy_type            = "SimpleScaling"
  scaling_adjustment     = "-1"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
}

#Alarm for Scale up
resource "aws_cloudwatch_metric_alarm" "alarm_scale_up" {
  alarm_name          = "alarm_scale_up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 5
  alarm_description   = "This metric monitors ec2 cpu utilization"
  # insufficient_data_actions = []
  dimensions = {
    "AutoScalingGroupName" = aws_autoscaling_group.asg.name
  }
  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.scale_up_policy.arn]
}

#Alarm for  scale down
resource "aws_cloudwatch_metric_alarm" "alarm_scale_down" {
  alarm_name          = "alarm_scale_down"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 3
  alarm_description   = "This metric monitors ec2 cpu utilization"
  # insufficient_data_actions = []
  dimensions = {
    "AutoScalingGroupName" = aws_autoscaling_group.asg.name
  }
  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.scale_down_policy.arn]
}

resource "aws_lb" "lb" {
  name               = "csye6225-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [local.public_subnet_ids[0], local.public_subnet_ids[1], local.public_subnet_ids[2]]
  tags = {
    Application = "WebApp"
  }
}

resource "aws_lb_target_group" "alb_tg" {
  name        = "csye6225-lb-alb-tg"
  port        = 5050
  protocol    = "HTTP"
  vpc_id      = aws_vpc.webapp_vpc.id
  target_type = "instance"
  health_check {
    # interval            = 30
    path = "/healthz"
    # port                = "traffic-port"
    # protocol            = "HTTP"
    # healthy_threshold   = 5
    # unhealthy_threshold = 2
  }
}
data "aws_acm_certificate" "webapp_cert" {
  domain   = var.domain_name
  statuses = ["ISSUED"]
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = data.aws_acm_certificate.webapp_cert.arn
  default_action {
    target_group_arn = aws_lb_target_group.alb_tg.arn
    type             = "forward"
  }
}

# resource "aws_instance" "webapp_instance" {
#   ami                    = var.my_ami                     # Set the ID of the Amazon Machine Image to use
#   instance_type          = "t2.micro"                     # Set the instance type
#   key_name               = "aws_key"                          # Set the key pair to use for SSH access
#   vpc_security_group_ids = [aws_security_group.app_sg.id] # Set the security group to attach to the instance
#   subnet_id              = local.public_subnet_ids[0]     # Set the ID of the subnet to launch the instance in
#   # Enable protection against accidental termination
#   disable_api_termination = false
#   # Set the root volume size and type
#   root_block_device {
#     volume_size           = 20    # Replace with your preferred root volume size (in GB)
#     volume_type           = "gp2" # Replace with your preferred root volume type (e.g. "gp2", "io1", etc.)
#     delete_on_termination = true
#   }
#   depends_on           = [aws_db_instance.rds_instance]
#   iam_instance_profile = aws_iam_instance_profile.iam_profile.name
#   user_data            = <<EOF
# #!/bin/bash
# cd /home/ec2-user || return
# touch application.properties
# sudo chown ec2-user:ec2-user application.properties
# sudo chmod 775 application.properties
# echo "aws.region=${var.aws_region}" >> application.properties
# echo "aws.s3.bucketName=${aws_s3_bucket.s3b.bucket}" >> application.properties
# echo "server.port=5050" >> application.properties
# echo "spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver" >> application.properties
# echo "spring.datasource.url=jdbc:mysql://${aws_db_instance.rds_instance.endpoint}/${aws_db_instance.rds_instance.db_name}?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC" >> application.properties
# echo "spring.datasource.username=${aws_db_instance.rds_instance.username}" >> application.properties
# echo "spring.datasource.password=${aws_db_instance.rds_instance.password}" >> application.properties
# echo "#spring.jpa.properties.hibernate.dialect = org.hibernate.dialect.MySQL5InnoDBDialect" >> application.properties
# echo "spring.jpa.hibernate.ddl-auto=update" >> application.properties
# echo "logging.file.path=/home/ec2-user" >> application.properties
# echo "logging.file.name=/home/ec2-user/csye6225.log" >> application.properties
# echo "publish.metrics=true" >> application.properties
# echo "metrics.server.hostname=localhost" >> application.properties
# echo "metrics.server.port=8125" >> application.properties
# sudo chmod 770 /home/ec2-user/webapp-0.0.1-SNAPSHOT.jar
# sudo cp /tmp/webservice.service /etc/systemd/system
# sudo cp /tmp/cloudwatch-config.json /opt/cloudwatch-config.json
# sudo chmod 770 /opt/cloudwatch-config.json
# sudo chmod 770 /etc/systemd/system/webservice.service
# sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
#     -a fetch-config \
#     -m ec2 \
#     -c file:/opt/cloudwatch-config.json \
#     -s
# sudo systemctl daemon-reload
# sudo systemctl start webservice.service
# sudo systemctl enable webservice.service
#   EOF

#   tags = {
#     Name = "webapp-instance-${timestamp()}" # Set the name tag for the instance
#   }
# }

resource "random_pet" "rg" {
  keepers = {
    random_name = "webapp"
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
  bucket                  = aws_s3_bucket.s3b.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
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

resource "aws_iam_policy_attachment" "web-app-atach-cloudwatch" {
  name       = "attach-cloudwatch-server-policy-ec2"
  roles      = [aws_iam_role.ec2-role.name]
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}


resource "aws_iam_instance_profile" "iam_profile" {
  name = "iam_profile_1"
  role = aws_iam_role.ec2-role.name
}

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
  name                 = var.db_name
  username             = var.db_username
  password             = var.db_password
  publicly_accessible  = var.db_public_access
  multi_az             = var.db_multiaz
  parameter_group_name = aws_db_parameter_group.rds_parameter_group.name
  skip_final_snapshot  = true
  kms_key_id = aws_kms_key.webapp-kms-rds.arn
  # kms_key_id = data.aws_kms_key.webapp-rds-kms.arn
  storage_encrypted     = true
  tags = {
    "Name" = "rds-${timestamp()}"
  }
}

# Look up the Route53 zone ID for the specified domain name
data "aws_route53_zone" "hosted_zone" {
  name         = var.domain_name
  private_zone = false
}

# Create Route53 record
resource "aws_route53_record" "hosted_zone_record" {
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  name    = var.domain_name
  type    = "A"
  # ttl     = "60"
  alias {
    name                   = aws_lb.lb.dns_name
    zone_id                = aws_lb.lb.zone_id
    evaluate_target_health = true
  }
  # records = [aws_lb.lb.load_balancer_ip]
}

