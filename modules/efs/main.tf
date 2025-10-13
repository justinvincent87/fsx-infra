resource "aws_security_group_rule" "efs_nfs" {
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = var.security_group_ids[0]
  source_security_group_id = var.security_group_ids[0]
  description              = "Allow NFS from EC2 SG"
}
# EFS Module

variable "name" {}
variable "vpc_id" {}
variable "subnet_ids" { type = list(string) }
variable "security_group_ids" { type = list(string) }
variable "tags" { type = map(string) }

resource "aws_efs_file_system" "this" {
  creation_token = var.name
  tags           = var.tags
}

resource "aws_efs_mount_target" "this" {
  count           = length(var.subnet_ids)
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = var.security_group_ids
}

output "efs_id" {
  value = aws_efs_file_system.this.id
}
output "efs_dns_name" {
  value = aws_efs_file_system.this.dns_name
}
