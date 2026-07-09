locals {
  tags = {
    ManagedBy = "Terraform"
    Project   = "learn-hcl"
  }
}

resource "aws_s3_bucket" "site" {
  bucket = var.bucket_name
  tags   = local.tags
}