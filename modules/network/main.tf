// infra/modules/network/main.tf
terraform {
  required_providers {
    aws = { source = "hashicorp/aws" }
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(var.tags, { "Name" = "${var.name}-vpc" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { "Name" = "${var.name}-igw" })
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index % length(var.azs)]
  map_public_ip_on_launch = true
  tags                    = merge(var.tags, { "Name" = "${var.name}-public-${count.index}", "kubernetes.io/role/elb" = "1" })
}


# One NAT Gateway per AZ (and EIP)
resource "aws_eip" "nat" {
  count  = length(var.azs)
  domain = "vpc"
  tags   = merge(var.tags, { "Name" = "${var.name}-nat-${count.index}" })
}

resource "aws_nat_gateway" "nat" {
  count         = length(var.azs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = merge(var.tags, { "Name" = "${var.name}-nat-${count.index}" })
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index % length(var.azs)]
  tags              = merge(var.tags, { "Name" = "${var.name}-private-${count.index}" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { "Name" = "${var.name}-public-rt" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}


# One private route table per AZ, each associated with a NAT in that AZ
resource "aws_route_table" "private" {
  count  = length(var.azs)
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { "Name" = "${var.name}-private-rt-${count.index}" })
}

resource "aws_route" "private_nat" {
  count                  = length(var.azs)
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[count.index].id
}

# Associate each private subnet with the route table in its AZ
resource "aws_route_table_association" "private_assoc" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index % length(var.azs)].id
}
# VPC Endpoints for S3 and Secrets Manager
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat([aws_route_table.public.id], aws_route_table.private[*].id)
  tags              = merge(var.tags, { "Name" = "${var.name}-s3-endpoint" })
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id             = aws_vpc.this.id
  service_name       = "com.amazonaws.${var.region}.secretsmanager"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [data.aws_security_group.default.id]
  tags               = merge(var.tags, { "Name" = "${var.name}-secretsmanager-endpoint" })
}


output "nat_gateway_ids" {
  value = aws_nat_gateway.nat[*].id
}

output "eip_ids" {
  value = aws_eip.nat[*].id
}

output "public_route_table_id" {
  value = aws_route_table.public.id
}

output "private_route_table_ids" {
  value = aws_route_table.private[*].id
}

output "igw_id" {
  value = aws_internet_gateway.igw.id
}

output "s3_vpc_endpoint_id" {
  value = aws_vpc_endpoint.s3.id
}

output "secretsmanager_vpc_endpoint_id" {
  value = aws_vpc_endpoint.secretsmanager.id
}

# Fetch the default security group for the VPC
data "aws_security_group" "default" {
  name   = "default"
  vpc_id = aws_vpc.this.id
}

# Allow inbound TCP on port 81 from anywhere for ALB (if using default SG)
resource "aws_security_group_rule" "alb_81_inbound" {
  type              = "ingress"
  from_port         = 81
  to_port           = 81
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = data.aws_security_group.default.id
  description       = "Allow HTTP for ALB auth listener on port 81"
}

output "default_sg_id" {
  value = data.aws_security_group.default.id
}
