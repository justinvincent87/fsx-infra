# S3 Module

variable "bucket_name" {}
variable "tags" { type = map(string) }

resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
  tags   = var.tags
}

output "bucket_arn" {
  value = aws_s3_bucket.this.arn
}
