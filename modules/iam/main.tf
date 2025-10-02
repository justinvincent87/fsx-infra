variable "name" { type = string }
variable "tags" {
  description = "A map of tags to assign to resources."
  type        = map(string)
  default     = {}
}

resource "aws_iam_role" "ci_assume" {
  name = "${var.name}-ci-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { AWS = var.trusted_account_arn } # CI runner or central account ARN
      Action = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

variable "trusted_account_arn" { type = string }

resource "aws_iam_role_policy" "ci_policy" {
  name = "${var.name}-ci-policy"
  role = aws_iam_role.ci_assume.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:*",
          "dynamodb:*",
          "ec2:*",
          "iam:PassRole",
          "rds:*",
          "elasticloadbalancing:*",
          "cloudwatch:*",
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })
}
output "ci_role_arn" { value = aws_iam_role.ci_assume.arn }
