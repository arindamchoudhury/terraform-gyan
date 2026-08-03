# Chapter 11 Lab, Part C — create_before_destroy where the name cannot move.
#
# A DynamoDB table's name is fixed and its hash_key forces replacement. Creating
# the replacement first therefore means two tables with the same name, which the
# API refuses. This is the constraint that keeps create_before_destroy opt-in.
#
#   tflocal init
#   tflocal apply -auto-approve
#   tflocal apply -var hash_key=tenant_id -auto-approve   # fails at apply

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

variable "hash_key" {
  description = "Changing the hash key forces replacement of the table."
  type        = string
  default     = "session_id"
}

resource "aws_dynamodb_table" "sessions" {
  name         = "ch11-sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = var.hash_key

  attribute {
    name = var.hash_key
    type = "S"
  }

  lifecycle {
    create_before_destroy = true
  }
}
