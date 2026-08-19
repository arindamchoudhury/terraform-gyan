# Lab 2, step 1 — bootstrap the state bucket with a LOCAL backend.
#
# The chicken-and-egg every remote-state setup starts with: the bucket that will
# hold your state cannot be tracked in that state before it exists. The answer is
# two configurations. This one runs on the local backend and creates the bucket;
# ../app then keeps its state inside it.
#
#   source "$(git rev-parse --show-toplevel)/labs/lab-env.sh"
#   tflocal init && tflocal apply

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  # No backend block. This configuration stays local on purpose.
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "state" {
  bucket = "tf-state-lab"

  # The chapter's version of this configuration adds:
  #
  #   lifecycle {
  #     prevent_destroy = true
  #   }
  #
  # It is deliberately left out here so the lab can be torn down with
  # `tflocal destroy`. On a real state bucket, put it back. Losing the bucket
  # loses every project's state at once, and prevent_destroy is a plan-time
  # refusal rather than a warning.
}

# Versioning is what makes a truncated or corrupted state recoverable. The S3
# backend page recommends it; nothing turns it on for you.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# State is plaintext secrets. On a real bucket this block is not optional.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "bucket" {
  value = aws_s3_bucket.state.id
}
