# Generate an SSH key pair for EC2 access
resource "tls_private_key" "ec2" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# New key pair for app EC2s
resource "tls_private_key" "app" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "app" {
  key_name   = "fsx-app-key"
  public_key = tls_private_key.app.public_key_openssh
}

resource "aws_key_pair" "ec2" {
  key_name   = "fsx-ec2-key"
  public_key = tls_private_key.ec2.public_key_openssh
}

output "ec2_private_key_pem" {
  value     = tls_private_key.ec2.private_key_pem
  sensitive = true
}

# Terraform configuration block: specifies required Terraform and provider versions
terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}


# Input variables for environment and AWS account configuration
variable "region" { default = "us-east-1" }
variable "account_id" { default = "718277287949" }
variable "org" { default = "fsx" }
variable "env" { default = "prod" }


# AWS provider configuration: region is set from variable
provider "aws" {
  region = var.region
  # profile = "terraform"
}


# Network module: provisions VPC, subnets, NAT gateways, route tables, and VPC endpoints
module "network" {
  source               = "../../modules/network"
  name                 = "${var.org}-${var.env}"
  vpc_cidr             = "10.10.0.0/16"                                         # Main VPC CIDR block
  public_subnet_cidrs  = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]       # Public subnets for ALB, web, etc.
  private_subnet_cidrs = ["10.10.11.0/24", "10.10.12.0/24", "10.10.13.0/24"]    # Private subnets for app and DB
  azs                  = ["${var.region}a", "${var.region}b", "${var.region}c"] # Availability Zones
  nat_count            = [0, 1, 2]                                              # NAT gateway mapping
  tags = {
    Environment = var.env
    Project     = var.org
    ManagedBy   = "terraform"
  }
  region = var.region
}


# IAM module: creates IAM roles and policies for EC2 and other resources
module "iam" {
  source              = "../../modules/iam"
  name                = "${var.org}-${var.env}"
  trusted_account_arn = "arn:aws:iam::${var.account_id}:root"
  tags = {
    Environment = var.env
  }
}





# EC2 module: provisions 5 EC2 instances for different app modules
module "ec2" {
  source = "../../modules/ec2"
  vpc_id = module.network.vpc_id
  instances = [
    # Bastion host (public subnet, t2.nano, uses fsx-ec2-key)
    {
      name          = "fsx-bastion"
      subnet_id     = module.network.public_subnet_ids[2]
      instance_type = "t2.nano"
      ami_id        = "ami-0c94855ba95c71c99"
      port          = 22
      public        = true
      key_name      = aws_key_pair.ec2.key_name
      tags = {
        Environment = var.env
        Project     = var.org
        Role        = "fsx-bastion"
      }
    },
    # Instance 1: fsx-production (private subnet, port 9001)
    {
      name          = "fsx-production"
      subnet_id     = module.network.private_subnet_ids[0]
      instance_type = "m5.xlarge"
      ami_id        = "ami-0c94855ba95c71c99"
      port          = 9001
      public        = false
      key_name      = aws_key_pair.app.key_name
      tags = {
        Environment = var.env
        Project     = var.org
        Role        = "fsx-production"
      }
    },
    # Instance 2: fsx-planning (private subnet, port 9002)
    {
      name          = "fsx-planning"
      subnet_id     = module.network.private_subnet_ids[1]
      instance_type = "m5.xlarge"
      ami_id        = "ami-0c94855ba95c71c99"
      port          = 9002
      public        = false
      key_name      = aws_key_pair.app.key_name
      tags = {
        Environment = var.env
        Project     = var.org
        Role        = "fsx-planning"
      }
    },
    # Instance 3: fsx-scheduler (private subnet, port 9006)
    {
      name          = "fsx-scheduler"
      subnet_id     = module.network.private_subnet_ids[2]
      instance_type = "m5.2xlarge"
      ami_id        = "ami-0c94855ba95c71c99"
      port          = 9006
      public        = false
      key_name      = aws_key_pair.app.key_name
      tags = {
        Environment = var.env
        Project     = var.org
        Role        = "fsx-scheduler"
      }
    },
    # Instance 4: fsx-web (private subnet, port 8001)
    {
      name          = "fsx-web"
      subnet_id     = module.network.private_subnet_ids[0]
      instance_type = "m5.xlarge"
      ami_id        = "ami-0c94855ba95c71c99"
      port          = 8001
      public        = false
      key_name      = aws_key_pair.app.key_name
      tags = {
        Environment = var.env
        Project     = var.org
        Role        = "fsx-web"
      }
    },
    # Instance 5: fsx-auth-server (private subnet, port 8080)
    {
      name          = "fsx-auth-server"
      subnet_id     = module.network.private_subnet_ids[1]
      instance_type = "m5.xlarge"
      ami_id        = "ami-0c94855ba95c71c99"
      port          = 8080
      public        = false
      key_name      = aws_key_pair.app.key_name
      tags = {
        Environment = var.env
        Project     = var.org
        Role        = "fsx-auth-server"
      }
    }
  ]
}


# RDS module: provisions MySQL database in private subnets
module "rds" {
  source                 = "../../modules/rds"
  name                   = "${var.org}-${var.env}-mysql"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.medium"
  allocated_storage      = 20
  username               = "fsxadmin"         # Use Secrets Manager for production
  password               = "qzMZRi7FlTzBWXop" # Use Secrets Manager for production
  subnet_ids             = module.network.private_subnet_ids
  vpc_security_group_ids = [module.ec2.app_sg_id] # Allow MySQL from EC2 SG
  tags = {
    Environment = var.env
    Project     = var.org
  }
}


# S3 module: creates an S3 bucket for file storage
module "s3" {
  source      = "../../modules/s3"
  bucket_name = "${var.org}-${var.env}-resources"
  tags = {
    Environment = var.env
    Project     = var.org
  }
}


# ALB module: provisions Application Load Balancer for public-facing services
module "alb" {
  source             = "../../modules/alb"
  name               = "${var.org}-${var.env}-alb"
  vpc_id             = module.network.vpc_id
  subnet_ids         = module.network.public_subnet_ids
  security_group_ids = [module.network.default_sg_id]
  # Pass both instance IDs: [web, auth]
  target_instance_ids = [module.ec2.instance_ids[3], module.ec2.instance_ids[4]]
  web_port            = 80
  auth_port           = 8080
  tags = {
    Environment = var.env
    Project     = var.org
  }
}

# Outputs: VPC ID and CI IAM role ARN
output "vpc_id" { value = module.network.vpc_id }
output "ci_role" { value = module.iam.ci_role_arn }
