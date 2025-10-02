# Operations Guide for FSX AWS Infrastructure

## Daily Operations

- Monitor EC2, RDS, and ALB health in AWS Console.
- Review CloudWatch logs and alarms.
- Check S3 bucket for file uploads and lifecycle policies.

## Common Tasks

- Scaling EC2: Update instance count/types in `main.tf` and re-apply Terraform.
- Database maintenance: Use AWS Console for backups, restores, and monitoring.
- IAM: Rotate access keys and review permissions regularly.

## Troubleshooting

- Use `terraform plan` to review pending changes.
- Use `terraform state` to inspect resources.
- Check AWS Console for resource status and logs.

## Security

- Review security group rules and IAM policies regularly.
- Ensure only required ports are open to the public.
- Use Secrets Manager for sensitive data.

## Backups & Recovery

- RDS automated backups are enabled.
- S3 versioning and lifecycle rules are enabled.
- Regularly test restore procedures.
