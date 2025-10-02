# Migration Plan for FSX Application

## 1. Pre-Migration Planning

- Finalize AWS region (must have two Availability Zones).
- Confirm production SLAs (RTO/RPO, latency, scaling thresholds).
- Collect application inventory: 4 Spring Boot microservices, Keycloak, NGINX, MySQL schema, file server migration.
- Define VPC CIDR range (no overlap with on-prem).
- Identify external APIs and whitelist NAT EIP addresses if required.
- Confirm DNS and SSL/TLS certificate strategy.

## 2. Migration Steps

1. Provision AWS infrastructure using Terraform (see root README).
2. Migrate MySQL schema and data to Aurora MySQL.
3. Upload files to S3 bucket.
4. Deploy application modules to EC2 instances.
5. Update DNS records and SSL certificates.
6. Validate application and database connectivity.

## 3. Post-Migration

- Monitor application and infrastructure health.
- Enable CloudWatch alarms and dashboards.
- Review security and compliance settings.
