# Chapter 12 Lab, Part B — nesting a dynamic block inside a dynamic block.
#
#   tflocal init
#   tflocal apply -auto-approve
#   awslocal s3api get-bucket-lifecycle-configuration --bucket ch12-archive
#   tflocal destroy -auto-approve
#
# Three levels are in play. The outer `rule` blocks come from a map, so the map
# key becomes the rule id. Inside each rule, `transition` blocks come from that
# rule's own list. `filter` and `expiration` use the zero-or-one idiom, because
# each is a single optional block rather than a repeated one.

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

variable "lifecycle_rules" {
  description = "Keyed by rule id. Every field except the key is optional."

  type = map(object({
    prefix      = optional(string)
    expire_days = optional(number)
    transitions = optional(list(object({
      days          = number
      storage_class = string
    })), [])
  }))

  default = {
    logs = {
      prefix      = "logs/"
      expire_days = 365
      transitions = [
        { days = 30, storage_class = "STANDARD_IA" },
        { days = 90, storage_class = "GLACIER" },
      ]
    }
    tmp = {
      prefix      = "tmp/"
      expire_days = 7
    }
    everything = {
      transitions = [
        { days = 180, storage_class = "GLACIER" },
      ]
    }
  }
}

resource "aws_s3_bucket" "archive" {
  bucket = "ch12-archive"
}

resource "aws_s3_bucket_lifecycle_configuration" "archive" {
  bucket = aws_s3_bucket.archive.id

  dynamic "rule" {
    for_each = var.lifecycle_rules

    content {
      id     = rule.key # the map key names the rule
      status = "Enabled"

      # Zero-or-one: a single optional block, not a repeated one.
      dynamic "filter" {
        for_each = rule.value.prefix == null ? [] : [rule.value.prefix]
        content {
          prefix = filter.value
        }
      }

      dynamic "expiration" {
        for_each = rule.value.expire_days == null ? [] : [rule.value.expire_days]
        content {
          days = expiration.value
        }
      }

      # Genuinely nested iteration: one transition per element of THIS rule's list.
      # `rule.value` is the outer element; `transition.value` is the inner one.
      dynamic "transition" {
        for_each = rule.value.transitions
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }
    }
  }
}

output "rule_ids" {
  value = sort([for r in aws_s3_bucket_lifecycle_configuration.archive.rule : r.id])
}
