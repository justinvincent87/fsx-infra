# RDS Module

variable "name" {}
variable "engine" {}
variable "engine_version" {}
variable "instance_class" {}
variable "allocated_storage" {}
variable "username" {}
variable "password" {}
variable "subnet_ids" { type = list(string) }
variable "vpc_security_group_ids" { type = list(string) }
variable "tags" { type = map(string) }

resource "aws_db_instance" "this" {
  identifier              = var.name
  engine                  = var.engine
  engine_version          = var.engine_version
  instance_class          = var.instance_class
  allocated_storage       = var.allocated_storage
  username                = var.username
  password                = var.password
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = var.vpc_security_group_ids
  skip_final_snapshot     = true
  tags = var.tags
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-subnet-group"
  subnet_ids = var.subnet_ids
  tags       = var.tags
}

output "db_instance_endpoint" {
  value = aws_db_instance.this.endpoint
}
