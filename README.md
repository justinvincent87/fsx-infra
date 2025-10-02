# FSX Infra Terraform Project

This repository contains the Terraform code to provision the AWS infrastructure for the FSX application, including:

- VPC, subnets, NAT gateways, route tables
- Security groups and IAM roles
- EC2 instances for all application modules
- RDS (Aurora MySQL) database
- S3 bucket for file storage
- Application Load Balancer (ALB)
- VPC endpoints for S3 and Secrets Manager

## Getting Started

### Prerequisites

- Terraform >= 1.3.0
- AWS CLI
- AWS account with sufficient permissions

### Setup

1. Clone this repository.
2. Configure your AWS credentials (e.g., `aws configure`).
3. Review and update variables in `envs/prod/main.tf` as needed.
4. Initialize Terraform:
   ```sh
   terraform init
   ```
5. Review the plan:
   ```sh
   terraform plan
   ```
6. Apply the infrastructure:
   ```sh
   terraform apply
   ```

## Project Structure

- `envs/` - Environment-specific Terraform configurations (e.g., prod, npp)
- `modules/` - Reusable Terraform modules (network, ec2, rds, s3, alb, etc.)
- `docs/` - Documentation
- `ci/` - CI/CD scripts

## Modules

- **network**: VPC, subnets, NAT, route tables, endpoints
- **ec2**: Application EC2 instances, security groups, IAM roles
- **rds**: Aurora MySQL DB
- **s3**: File storage bucket
- **alb**: Application Load Balancer

## Security

- All EC2 instances can communicate with each other and access RDS and S3.
- Only web and auth-server instances are exposed to the public.
- IAM roles restrict access to only required AWS services.

## Monitoring & Logging

- CloudWatch log groups and alarms (to be implemented)

## Migration & Operations

- See `docs/migration.md` for migration steps.
- See `docs/operations.md` for operational procedures.

---

For more details, see the `docs/` directory.
