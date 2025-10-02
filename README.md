# Infra (Terraform)

Purpose: multi-env terraform code (NPP, PROD) with modular structure.

Pre-req:

- Terraform >= 1.3
- AWS CLI/profile or CI that can assume deployment role
- S3 bucket and DynamoDB table for state + locking created (or bootstrap via AWS console)

Bootstrap:

1. Create S3 bucket: tfstate-<ACCOUNT_ID>-<REGION>
2. Create DynamoDB table: tfstate-lock-<ACCOUNT_ID> (hash key: LockID)
3. Populate GitHub secrets: TF_S3_BUCKET, AWS_REGION, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
4. Run `terraform init` in envs/npp, plan, apply (CI will do the same).

Docs:

- Each module in `modules/` has README and params. Keep modules small and focused.
- Use per-env backend config files.
