terraform {
  required_version = ">= 1.15"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
  }
}

variable "name" { type = string }

resource "aws_s3_bucket" "this" {
  bucket = var.name
}

output "bucket" { value = aws_s3_bucket.this.id }
