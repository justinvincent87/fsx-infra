
# ============================================================================
# Terraform Configuration: Backend, Providers, and Required Versions
# ============================================================================

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

# ============================================================================
# Input Variables: Environment and AWS Account
# ============================================================================

variable "region" { default = "us-east-1" }
variable "account_id" { default = "718277287949" }
variable "org" { default = "fsx" }
variable "env" { default = "prod" }

# ============================================================================
# AWS Provider Configuration
# ============================================================================

provider "aws" {
  region = var.region
  # profile = "terraform"
}




# ============================================================================
# Network Module: VPC, Subnets, NAT, Endpoints
# ============================================================================

module "network" {
  source               = "../../modules/network"
  name                 = "${var.org}-${var.env}"
  vpc_cidr             = "10.10.0.0/16"
  public_subnet_cidrs  = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
  private_subnet_cidrs = ["10.10.11.0/24", "10.10.12.0/24", "10.10.13.0/24"]
  azs                  = ["${var.region}a", "${var.region}b", "${var.region}c"]
  nat_count            = [0, 1, 2]
  tags = {
    Environment = var.env
    Project     = var.org
    ManagedBy   = "terraform"
  }
  region = var.region
}

# ============================================================================
# IAM Module: Roles and Policies
# ============================================================================

module "iam" {
  source              = "../../modules/iam"
  name                = "${var.org}-${var.env}"
  trusted_account_arn = "arn:aws:iam::${var.account_id}:root"
  tags = {
    Environment = var.env
  }
}

# ============================================================================
# EC2 Module: Compute Instances (Bastion, App, Web, Auth, Scheduler)
# ============================================================================


# Bastion host module (single instance)
module "bastion" {
  source             = "../../modules/ec2"
  vpc_id             = module.network.vpc_id
  efs_dns_name       = ""
  efs_mount_path     = "/opt/filestore/data"
  bastion_private_ip = "0.0.0.0/0" # Not used for bastion itself
  name_prefix        = "bastion-"
  instances = [
    {
      name          = "fsx-bastion"
      subnet_id     = module.network.public_subnet_ids[2]
      instance_type = "m5.xlarge"
      ami_id        = "ami-0c94855ba95c71c99"
      port          = 22
      public        = true
      key_name      = "fsx-ec2-key"
      tags = {
        Environment = var.env
        Project     = var.org
        Role        = "fsx-bastion"
      }
    }
  ]
}

# All other EC2s (app, web, auth, scheduler)
module "ec2" {
  source             = "../../modules/ec2"
  vpc_id             = module.network.vpc_id
  efs_dns_name       = module.efs.efs_dns_name
  efs_mount_path     = "/opt/filestore/data"
  bastion_private_ip = module.bastion.private_ips[0]
  instances = [
    # Instance 1: fsx-production1 (private subnet, app server)
    {
      name          = "fsx-production1"
      subnet_id     = module.network.private_subnet_ids[0]
      instance_type = "m5.xlarge"
      ami_id        = "ami-0c94855ba95c71c99"
      port          = 9001
      public        = false
      key_name      = "fsx-app-key"
      tags = {
        Environment = var.env
        Project     = var.org
        Role        = "fsx-production"
      }
    },
    # Instance 2: fsx-production2 (private subnet, app server)
    {
      name          = "fsx-production2"
      subnet_id     = module.network.private_subnet_ids[1]
      instance_type = "m5.xlarge"
      ami_id        = "ami-0c94855ba95c71c99"
      port          = 9001
      public        = false
      key_name      = "fsx-app-key"
      tags = {
        Environment = var.env
        Project     = var.org
        Role        = "fsx-production"
      }
    },
    # Instance 3: fsx-scheduler (private subnet, scheduler)
    {
      name          = "fsx-scheduler"
      subnet_id     = module.network.private_subnet_ids[2]
      instance_type = "m5.2xlarge"
      ami_id        = "ami-0c94855ba95c71c99"
      port          = 9006
      public        = false
      key_name      = "fsx-app-key"
      tags = {
        Environment = var.env
        Project     = var.org
        Role        = "fsx-scheduler"
      }
    },
    # Instance 4: fsx-web (private subnet, web server)
    {
      name          = "fsx-web"
      subnet_id     = module.network.private_subnet_ids[0]
      instance_type = "m5.xlarge"
      ami_id        = "ami-0c94855ba95c71c99"
      port          = 8001
      public        = false
      key_name      = "fsx-app-key"
      tags = {
        Environment = var.env
        Project     = var.org
        Role        = "fsx-web"
      }
    },
    # Instance 5: fsx-auth-server (private subnet, auth server)
    {
      name          = "fsx-auth-server"
      subnet_id     = module.network.private_subnet_ids[1]
      instance_type = "m5.xlarge"
      ami_id        = "ami-0c94855ba95c71c99"
      port          = 8080
      public        = false
      key_name      = "fsx-app-key"
      tags = {
        Environment = var.env
        Project     = var.org
        Role        = "fsx-auth-server"
      }
    }
  ]
}

# ============================================================================
# EFS Module: Shared File Storage
# ============================================================================

module "efs" {
  source             = "../../modules/efs"
  name               = "${var.org}-${var.env}-efs"
  vpc_id             = module.network.vpc_id
  subnet_ids         = module.network.private_subnet_ids
  security_group_ids = [module.ec2.app_sg_id]
  tags = {
    Name        = "${var.org}-${var.env}-efs"
    web_port    = 9002
    Environment = var.env
    Project     = var.org
  }
}

# ============================================================================
# ALB Modules: Application Load Balancers for Web, API, Auth
# ============================================================================


module "alb_web" {
  source              = "../../modules/alb"
  name                = "${var.org}-${var.env}-alb-web"
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.public_subnet_ids
  security_group_ids  = [module.network.alb_sg_id]
  target_instance_ids = [module.ec2.instance_ids[3]]
  type                = "web"
  web_port            = 80
  tags = {
    Name        = "${var.org}-${var.env}-alb-web"
    Environment = var.env
    Project     = var.org
  }
}


module "alb_api" {
  source              = "../../modules/alb"
  name                = "${var.org}-${var.env}-alb-api"
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.public_subnet_ids
  security_group_ids  = [module.network.alb_sg_id]
  target_instance_ids = [module.ec2.instance_ids[0], module.ec2.instance_ids[1]]
  type                = "api"
  web_port            = 9001
  tags = {
    Name        = "${var.org}-${var.env}-alb-api"
    Environment = var.env
    Project     = var.org
  }
}


module "alb_auth" {
  source              = "../../modules/alb"
  name                = "${var.org}-${var.env}-alb-auth"
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.public_subnet_ids
  security_group_ids  = [module.network.alb_sg_id]
  target_instance_ids = [module.ec2.instance_ids[4]]
  type                = "auth"
  auth_port           = 8080
  tags = {
    Name        = "${var.org}-${var.env}-alb-auth"
    Environment = var.env
    Project     = var.org
  }
}




# ============================================================================
# RDS Module: MySQL Database
# ============================================================================

module "rds" {
  source                 = "../../modules/rds"
  name                   = "${var.org}-${var.env}-mysql"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.m6g.xlarge"
  allocated_storage      = 20
  username               = "fsxadmin"         # Use Secrets Manager for production
  password               = "qzMZRi7FlTzBWXop" # Use Secrets Manager for production
  subnet_ids             = module.network.private_subnet_ids
  vpc_security_group_ids = [module.ec2.app_sg_id] # Allow MySQL from EC2 SG

  # Automated backup configuration
  backup_retention_period = 7
  backup_window           = "21:30-22:30"         # IST 3:00 AM - 4:00 AM
  maintenance_window      = "mon:22:30-mon:23:30" # IST Monday 4:00 AM - 5:00 AM
  apply_immediately       = true                  # Apply changes immediately

  # Performance Insights
  performance_insights_enabled          = true
  performance_insights_retention_period = 7 # 7 days (free tier) or 731 days (paid)

  tags = {
    Environment = var.env
    Project     = var.org
  }
}

# ============================================================================
# S3 Module: File Storage Bucket
# ============================================================================

module "s3" {
  source      = "../../modules/s3"
  bucket_name = "${var.org}-${var.env}-resources"
  tags = {
    Environment = var.env
    Project     = var.org
  }
}

# ============================================================================
# Outputs: Useful Resource IDs
# ============================================================================

output "vpc_id" { value = module.network.vpc_id }
output "ci_role" { value = module.iam.ci_role_arn }
