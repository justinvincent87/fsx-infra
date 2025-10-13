# Normalize bastion_private_ip to always be a valid CIDR
locals {
  bastion_cidr = can(regex("/", var.bastion_private_ip)) ? var.bastion_private_ip : "${var.bastion_private_ip}/32"
}
variable "name_prefix" {
  description = "Prefix for all resource names (SG, IAM, etc). Use to avoid name collisions."
  type        = string
  default     = ""
}


variable "instances" {
  description = "List of maps describing each EC2 instance."
  type = list(object({
    name          = string
    subnet_id     = string
    instance_type = string
    ami_id        = string
    port          = number
    public        = bool
    key_name      = string
    tags          = map(string)
  }))
}

# The private IP of the bastion host (set from root module)
variable "bastion_private_ip" {
  description = "Private IP address of the bastion host."
  type        = string
}

variable "efs_dns_name" {
  description = "EFS DNS name to mount."
  type        = string
  default     = ""
}

variable "efs_mount_path" {
  description = "Path to mount EFS."
  type        = string
  default     = "/opt/filestore/data"
}

variable "vpc_id" {}

# Security group for all EC2s
resource "aws_security_group" "app" {
  # Allow outbound NFS (port 2049) to anywhere
  egress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow outbound NFS for EFS"
  }
  # Allow outbound SSH (port 22) to anywhere
  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow outbound SSH"
  }
  name        = "${var.name_prefix}ec2-app-sg"
  description = "Allow app ports, all internal, egress to RDS and S3"
  vpc_id      = var.vpc_id

  # Allow all traffic between instances in this SG
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  # Allow inbound for each app port (web and auth-server from anywhere, others from within VPC)
  dynamic "ingress" {
    for_each = [for idx, inst in var.instances : {
      idx    = idx
      port   = inst.port
      public = inst.public
    }]
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "tcp"
      cidr_blocks = ingress.value.public ? ["0.0.0.0/0"] : ["10.10.0.0/16"]
    }
  }

  # --- Custom Egress Rules for fsx-production1 and fsx-production2 ---
  # Allow egress to foodswing.erevive.cloud:443 (assume resolves to dynamic IP, allow 443 to any)
  # (merged with general HTTPS rule below)
  # Allow egress to 122.184.95.42:7101-7108
  egress {
    from_port   = 7101
    to_port     = 7108
    protocol    = "tcp"
    cidr_blocks = ["122.184.95.42/32"]
    description = "Allow to 122.184.95.42:7101-7108"
  }
  # Allow egress to Gmail SMTP 587
  egress {
    from_port   = 587
    to_port     = 587
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow Gmail SMTP"
  }
  # Allow egress to RDS MySQL (3306)
  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.10.0.0/16"]
    description = "Allow RDS MySQL"
  }
  # Allow egress to any IP on 80 and 443 (covers foodswing.erevive.cloud:443 as well)
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP to any"
  }
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS to any"
  }

  # --- Custom Egress Rules for fsx-scheduler ---
  # Allow egress to fsx-production1 and fsx-production2 on port 9001
  egress {
    from_port   = 9001
    to_port     = 9001
    protocol    = "tcp"
    cidr_blocks = ["10.10.0.0/16"]
    description = "Allow to production1/2:9001"
  }
  # Allow egress to 122.184.95.42:7201
  egress {
    from_port   = 7201
    to_port     = 7201
    protocol    = "tcp"
    cidr_blocks = ["122.184.95.42/32"]
    description = "Allow to 122.184.95.42:7201"
  }
  # Allow egress to RDS MySQL (3306)
  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.10.0.0/16"]
    description = "Allow RDS MySQL"
  }
  # Allow egress to any IP on 80 and 443
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP to any"
  }
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS to any"
  }

  tags = { Name = "${var.name_prefix}ec2-app-sg" }
  # Allow SSH from VPC range (same as app ports)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.10.0.0/16"]
  }
}

# IAM role for S3 access
resource "aws_iam_role" "ec2_s3" {
  name = "${var.name_prefix}ec2-s3-access-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "s3" {
  role       = aws_iam_role.ec2_s3.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_instance_profile" "ec2_s3" {
  name = "${var.name_prefix}ec2-s3-profile"
  role = aws_iam_role.ec2_s3.name
}

resource "aws_instance" "this" {
  count                       = length(var.instances)
  ami                         = var.instances[count.index].ami_id
  instance_type               = var.instances[count.index].instance_type
  subnet_id                   = var.instances[count.index].subnet_id
  vpc_security_group_ids      = [aws_security_group.app.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_s3.name
  associate_public_ip_address = var.instances[count.index].public
  key_name                    = var.instances[count.index].key_name
  tags                        = merge(var.instances[count.index].tags, { Name = var.instances[count.index].name })
  user_data = var.efs_dns_name != "" ? templatefile("${path.module}/user_data_efs.sh.tmpl", {
    efs_dns_name   = var.efs_dns_name
    efs_mount_path = var.efs_mount_path
  }) : null
}

output "instance_ids" {
  value = aws_instance.this[*].id
}


output "public_ips" {
  value = [for i in aws_instance.this : i.public_ip if i.public_ip != null]
}

output "public_dns" {
  value = [for i in aws_instance.this : i.public_dns if i.public_dns != null]
}

output "private_ips" {
  value = [for i in aws_instance.this : i.private_ip]
}

# Output the EC2 security group ID for use in RDS module
output "app_sg_id" {
  value = aws_security_group.app.id
}
