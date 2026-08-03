# Chapter 11 Lab, Part B — create_before_destroy: the plan symbol, the deposed
# object, and the propagation into a dependency's state.
#
#   tflocal init
#   tflocal apply -auto-approve
#   # then flip the suffix to force a replacement:
#   tflocal plan  -var suffix=v2                     # -/+  destroy then create
#   tflocal apply -var suffix=v2 -auto-approve
#   # now set create_before_destroy = true (main.tf.cbd) and repeat with v3:
#   cp main.tf.cbd main.tf
#   tflocal plan  -var suffix=v3                     # +/-  create then destroy
#   tflocal apply -var suffix=v3 -auto-approve
#   # propagation check — the dependency never declares a lifecycle block:
#   terraform show -json | python -m json.tool | grep -n create_before_destroy

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

variable "suffix" {
  description = "Changing this renames the app bucket, which forces replacement."
  type        = string
  default     = "v1"
}

# The dependency. It declares no lifecycle block at all.
resource "aws_s3_bucket" "config" {
  bucket = "ch11-cbd-config"
}

# The dependent. Renaming it forces replacement.
resource "aws_s3_bucket" "app" {
  bucket = "ch11-cbd-app-${var.suffix}"

  tags = {
    config_bucket = aws_s3_bucket.config.id
  }
}
