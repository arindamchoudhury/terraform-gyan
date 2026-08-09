# Chapter 12 Lab, Part E — what a dynamic block's for_each will swallow.
#
# Section 5 claims the toggle element's value is never read, so it can be
# anything. This lab is where that claim was measured. Each probe is a one-line
# edit to the `for_each` below, then `tflocal plan`.
#
#   tflocal init
#   tflocal plan                                   # for_each = [1]  -> one rule block
#
#   for_each = [null]                              # -> one rule block
#   for_each = [sensitive(1)]                      # -> one rule block
#   for_each = [aws_s3_bucket.b.id]                # unknown element, known length
#                                                  #    -> one rule block
#   for_each = split(",", aws_s3_bucket.b.id)      # unknown length
#                                                  #    -> + rule (known after apply)
#   for_each = {}                                  # -> no rule block at all
#
# Every probe is answered by `plan`. Nothing here is ever applied, so there is
# nothing to destroy afterwards.
#
# The count of elements is the whole story, and null is not a special case:
#   null -> 0 blocks, [] -> 0, [null] -> 1, [null, null] -> 2.
#
# The contrast is in contrast.tf.resource: the same three values are hard errors
# on a *resource's* for_each, because those values become instance addresses.
#
#   cp contrast.tf.resource contrast.tf && tflocal plan && rm contrast.tf

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

resource "aws_s3_bucket" "b" {
  bucket = "ch12-dyn"
}

resource "aws_s3_bucket_lifecycle_configuration" "l" {
  bucket = aws_s3_bucket.b.id

  dynamic "rule" {
    for_each = [1]
    content {
      id     = "expire"
      status = "Enabled"
      filter {}
      expiration {
        days = 30
      }
    }
  }
}
