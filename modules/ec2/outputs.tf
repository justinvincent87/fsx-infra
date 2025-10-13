output "bastion_private_ip" {
  value       = aws_instance.this[0].private_ip
  description = "Private IP address of the bastion host (assumes first instance is bastion)"
}
