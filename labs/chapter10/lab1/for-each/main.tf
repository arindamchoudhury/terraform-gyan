# Chapter 10 — Lab 1, part B: the same three buckets, addressed by key.
#
# Apply this as-is, then remove "logs" from var.bucket_names and run
# `tflocal plan`. Compare the counts with part A.

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
  description = "Buckets to create. Order is irrelevant here."
  type        = set(string)
  default     = ["assets", "logs", "media"]
}

resource "aws_s3_bucket" "site" {
  for_each = var.bucket_names

  bucket = "ch10-foreach-${each.key}"
}

output "addresses" {
  description = "Instance address -> bucket name."
  value       = { for k, b in aws_s3_bucket.site : "aws_s3_bucket.site[\"${k}\"]" => b.bucket }
}
