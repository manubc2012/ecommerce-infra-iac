terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Obtener la última AMI oficial de Amazon Linux 2023 (Version Pinning por familia)
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

# 1. Red Privada Virtual (VPC) aislada por ambiente
resource "aws_vpc" "ecommerce_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name        = "ecom-${var.env_name}-vpc"
    Environment = var.env_name
    ManagedBy   = "Terraform"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.ecommerce_vpc.id

  tags = {
    Name = "ecom-${var.env_name}-igw"
  }
}

resource "aws_subnet" "public_az1" {
  vpc_id                  = aws_vpc.ecommerce_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "ecom-${var.env_name}-subnet-az1"
  }
}

resource "aws_subnet" "public_az2" {
  vpc_id                  = aws_vpc.ecommerce_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "ecom-${var.env_name}-subnet-az2"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.ecommerce_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "az1_assoc" {
  subnet_id      = aws_subnet.public_az1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "az2_assoc" {
  subnet_id      = aws_subnet.public_az2.id
  route_table_id = aws_route_table.public_rt.id
}

# 2. Seguridad Perimetral (Security Group)
resource "aws_security_group" "web_sg" {
  name        = "ecom-${var.env_name}-web-sg"
  description = "Permite trafico HTTP controlado hacia el cluster e-commerce"
  vpc_id      = aws_vpc.ecommerce_vpc.id

  ingress {
    description = "HTTP publico"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "ecom-${var.env_name}-web-sg"
    Environment = var.env_name
  }
}

# 3. Plantilla de Cómputo Estandarizada (Launch Template)
resource "aws_launch_template" "webapp_lt" {
  name_prefix   = "ecom-${var.env_name}-lt-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>E-Commerce UPB - Ambiente: ${var.env_name} | Nodo activo</h1>" > /var/www/html/index.html
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "ecom-${var.env_name}-paas-node"
      Environment = var.env_name
      ManagedBy   = "Terraform"
    }
  }
}

# 4. Clúster Elástico Multi-AZ (Auto Scaling Group)
resource "aws_autoscaling_group" "ecommerce_asg" {
  name                = "ecom-${var.env_name}-asg"
  vpc_zone_identifier = [aws_subnet.public_az1.id, aws_subnet.public_az2.id]
  min_size            = var.asg_min_instances
  desired_capacity    = var.asg_desired_instances
  max_size            = var.asg_max_instances

  launch_template {
    id      = aws_launch_template.webapp_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Environment"
    value               = var.env_name
    propagate_at_launch = true
  }
}