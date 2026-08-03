# Chapter 11 Lab, Part E — replace_triggered_by, driven by a variable through
# terraform_data. A plain variable is illegal in replace_triggered_by because a
# variable has no planned action of its own; terraform_data gives it one.
#
#   tflocal init
#   tflocal apply -auto-approve
#   tflocal plan  -var revision=2      # the bucket is replaced
#   tflocal apply -var revision=2 -auto-approve

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

variable "revision" {
  description = "Bump this to force the bucket to be rebuilt."
  type        = number
  default     = 1
}

resource "terraform_data" "revision" {
  input = var.revision
}

resource "aws_s3_bucket" "cache" {
  bucket = "ch11-cache"

  lifecycle {
    replace_triggered_by = [terraform_data.revision]
  }
}
