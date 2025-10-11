variable "key_name" {
  description = "The name of the SSH key pair to use for EC2 instances."
  type        = string
  default     = null
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
    tags          = map(string)
  }))
}

variable "vpc_id" {}

# Security group for all EC2s
resource "aws_security_group" "app" {
  name        = "ec2-app-sg"
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

  # Allow egress to RDS (MySQL)
  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.10.0.0/16"]
  }

  # Allow egress to S3 (HTTPS)
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all other egress
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ec2-app-sg" }
  # Allow SSH from anywhere (for production, restrict to your IP)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM role for S3 access
resource "aws_iam_role" "ec2_s3" {
  name = "ec2-s3-access-role"
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
  name = "ec2-s3-profile"
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
  key_name                    = var.key_name
  tags                        = merge(var.instances[count.index].tags, { Name = var.instances[count.index].name })
  user_data                   = null
}

output "instance_ids" {
  value = aws_instance.this[*].id
}

output "public_ips" {
  value = [for i in aws_instance.this : i.public_ip]
}

output "private_ips" {
  value = [for i in aws_instance.this : i.private_ip]
}
