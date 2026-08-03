# Chapter 11 Lab, Part A — prevent_destroy, and the hole in it.
#
#   tflocal init
#   tflocal apply -auto-approve
#   tflocal destroy                # rejected: Instance cannot be destroyed
#   cp main.tf.removed main.tf     # the guard is deleted along with the block
#   tflocal apply -auto-approve    # the bucket is destroyed anyway

terraform {
  required_version = ">= 1.15"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "audit_logs" {
  bucket = "ch11-audit-logs"

  lifecycle {
    prevent_destroy = true
  }
}

output "bucket" {
  value = aws_s3_bucket.audit_logs.bucket
}
