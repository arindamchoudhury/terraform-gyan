# Chapter 13 lab 1 — a local child module.
# Four resources behind three inputs. No provider block: it inherits the caller's.

terraform {
  required_version = ">= 1.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

locals {
  # Not a variable on purpose: the module's whole point is that these buckets
  # are never public, so the caller does not get a say.
  block_all_public_access = true
}

resource "aws_s3_bucket" "this" {
  bucket = var.name

  tags = merge(var.tags, {
    ManagedBy = "data-bucket-module"
    Reviewed  = "2026-08-08"
    Layer     = var.layer
  })
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = local.block_all_public_access
  block_public_policy     = local.block_all_public_access
  ignore_public_acls      = local.block_all_public_access
  restrict_public_buckets = local.block_all_public_access
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
