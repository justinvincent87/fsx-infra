terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

variable "region" { default = "us-east-1" }
variable "account_id" { default = "718277287949" }
variable "org" { default = "fsx" }
variable "env" { default = "prod" }

provider "aws" {
  region = var.region
  # profile = "terraform"
}

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

module "iam" {
  source              = "../../modules/iam"
  name                = "${var.org}-${var.env}"
  trusted_account_arn = "arn:aws:iam::${var.account_id}:root"
  tags = {
    Environment = var.env
  }
}
module "ec2" {
  source = "../../modules/ec2"
  vpc_id = module.network.vpc_id
  instances = [
    {
      name          = "fsx-production"
      subnet_id     = module.network.private_subnet_ids[0]
      instance_type = "m5.xlarge"
      ami_id        = "ami-0c94855ba95c71c99" # Replace with your AMI
      port          = 9001
      public        = false
      tags = {
        Environment = var.env
        Project     = var.org
        Role        = "fsx-production"
      }
    },
    {
      name          = "fsx-planning"
      subnet_id     = module.network.private_subnet_ids[1]
      instance_type = "m5.xlarge"
      ami_id        = "ami-0c94855ba95c71c99"
      port          = 9002
      public        = false
      tags = {
        Environment = var.env
        Project     = var.org
        Role        = "fsx-planning"
      }
    },
    {
      name          = "fsx-scheduler"
      subnet_id     = module.network.private_subnet_ids[2]
      instance_type = "m5.2xlarge"
      ami_id        = "ami-0c94855ba95c71c99"
      port          = 9006
      public        = false
      tags = {
        Environment = var.env
        Project     = var.org
        Role        = "fsx-scheduler"
      }
    },
    {
      name          = "fsx-web"
      subnet_id     = module.network.public_subnet_ids[0]
      instance_type = "m5.xlarge"
      ami_id        = "ami-0c94855ba95c71c99"
      port          = 8001
      public        = true
      tags = {
        Environment = var.env
        Project     = var.org
        Role        = "fsx-web"
      }
    },
    {
      name          = "fsx-auth-server"
      subnet_id     = module.network.public_subnet_ids[1]
      instance_type = "m5.xlarge"
      ami_id        = "ami-0c94855ba95c71c99"
      port          = 8002
      public        = true
      tags = {
        Environment = var.env
        Project     = var.org
        Role        = "fsx-auth-server"
      }
    }
  ]
}

module "rds" {
  source                 = "../../modules/rds"
  name                   = "${var.org}-${var.env}-mysql"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.medium"
  allocated_storage      = 20
  username               = "fsxadmin"
  password               = "qzMZRi7FlTzBWXop"
  subnet_ids             = module.network.private_subnet_ids
  vpc_security_group_ids = [module.network.default_sg_id]
  tags = {
    Environment = var.env
    Project     = var.org
  }
}

module "s3" {
  source      = "../../modules/s3"
  bucket_name = "${var.org}-${var.env}-resources"
  tags = {
    Environment = var.env
    Project     = var.org
  }
}

module "alb" {
  source              = "../../modules/alb"
  name                = "${var.org}-${var.env}-alb"
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.public_subnet_ids
  security_group_ids  = [module.network.default_sg_id]
  target_instance_ids = module.ec2.instance_ids
  tags = {
    Environment = var.env
    Project     = var.org
  }
}
output "vpc_id" { value = module.network.vpc_id }
output "ci_role" { value = module.iam.ci_role_arn }
