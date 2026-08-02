# Chapter 10 — Lab 1, part A: three buckets addressed by position.
#
# Apply this as-is, then delete "logs" from var.bucket_names and run
# `tflocal plan`. Watch how many instances Terraform proposes to touch.

terraform {
  required_version = ">= 1.15"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "bucket_names" {
  description = "Buckets to create, in order."
  type        = list(string)
  default     = ["assets", "logs", "media"]
}

resource "aws_s3_bucket" "site" {
  count = length(var.bucket_names)

  bucket = "ch10-count-${var.bucket_names[count.index]}"
}

output "addresses" {
  description = "Instance address -> bucket name."
  value       = { for i, b in aws_s3_bucket.site : "aws_s3_bucket.site[${i}]" => b.bucket }
}
