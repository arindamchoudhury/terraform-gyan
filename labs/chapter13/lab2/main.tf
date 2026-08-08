# Chapter 13 lab 2 — a registry module, and what a version constraint actually
# selects. Start with a deliberately loose constraint, then tighten it.

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

module "logs" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.1"

  bucket = "ch13-lab2-logs"

  # The module's own inputs. Everything here that is not `source` or `version`
  # is passed to a `variable` block inside the module.
  versioning = {
    enabled = true
  }

  tags = {
    Purpose = "chapter13-lab"
  }
}

output "logs_bucket_arn" {
  description = "Re-exported so `terraform output` can see it at all."
  value       = module.logs.s3_bucket_arn
}
