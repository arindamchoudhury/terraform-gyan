# Chapter 10 — Lab 2, step 1: the starting point, addressed by position.
#
# Apply this, then replace this file's resource block with the contents of
# `main.tf.after` (for_each + moved blocks) and run `tflocal plan`. A correct
# migration plans "No changes."
#
# Bucket names deliberately do NOT change across the migration, so the only
# thing moving is the resource address.

terraform {
  required_version = ">= 1.15"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}

provider "aws" {
  region = "us-east-1"
}

locals {
  bucket_names = ["assets", "logs", "media"]
}

resource "aws_s3_bucket" "site" {
  count = length(local.bucket_names)

  bucket = "ch10-migrate-${local.bucket_names[count.index]}"
}
