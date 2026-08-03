# Chapter 11 Lab, Part F — propagated create_before_destroy breaking a resource
# that never asked for it.
#
# The bucket declares create_before_destroy. The table does not, but the bucket
# depends on it, so the table inherits the rule. The table's name is fixed and
# its hash_key forces replacement, so create-first collides.
#
#   tflocal init
#   tflocal apply -auto-approve
#   tflocal apply -var hash_key=tenant_id -auto-approve   # fails on the TABLE

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
  type    = string
  default = "session_id"
}

# No lifecycle block. It inherits one.
resource "aws_dynamodb_table" "sessions" {
  name         = "ch11-prop-sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = var.hash_key

  attribute {
    name = var.hash_key
    type = "S"
  }
}

resource "aws_s3_bucket" "app" {
  bucket = "ch11-prop-app"

  tags = {
    table = aws_dynamodb_table.sessions.id
  }

  lifecycle {
    create_before_destroy = true
  }
}
