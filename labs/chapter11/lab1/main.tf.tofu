# Chapter 11 Lab, Part A — the OpenTofu run of the same measurement.
#
# Identical to main.tf except for required_version and the bucket name.
# main.tf pins >= 1.15, which OpenTofu 1.12.4 refuses; the bucket is renamed
# so both runs can coexist on one emulator.
#
#   cp main.tf.tofu main.tf              # in a scratch copy of this directory
#   TF_CMD=tofu tflocal init
#   TF_CMD=tofu tflocal apply -auto-approve
#   TF_CMD=tofu tflocal destroy          # refused: Resource instance cannot be
#                                        # destroyed, suggesting -exclude
#   cp main.tf.removed main.tf           # then drop the bucket block entirely
#   TF_CMD=tofu tflocal apply -auto-approve   # destroyed anyway: the same hole
#
# On this machine Norton intercepts the plugin's loopback mTLS, so each command
# above may need TF_DISABLE_PLUGIN_TLS=1 in front of it. Scope it per command.

terraform {
  required_version = ">= 1.12"
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
  bucket = "ch11-tofu-audit-logs"

  lifecycle {
    prevent_destroy = true
  }
}

output "bucket" {
  value = aws_s3_bucket.audit_logs.bucket
}
