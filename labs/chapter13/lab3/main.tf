# Chapter 13 lab 3 — a Git module source, built entirely on your own machine.
#
# Run setup.ps1 / setup.sh first. It creates a throwaway Git repository in your
# temp directory, tags it v0.0.1 and v0.0.2, and writes repo.auto.tfvars with
# the file:// URL of that repo.
#
# The source address is composed from two `const = true` variables, which is
# Terraform 1.15's dynamic module sources. Module installation happens at
# `init`, before plan-time evaluation exists, so anything feeding `source` has
# to be resolvable that early — `const` is how a variable promises that.

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

variable "module_repo" {
  description = "file:// URL of the throwaway module repo created by setup.ps1 / setup.sh."
  type        = string
  const       = true
}

variable "module_ref" {
  description = "Git revision to pin: a tag, a branch, or a full commit SHA."
  type        = string
  const       = true
  default     = "v0.0.1"
}

variable "module_depth" {
  description = "Shallow-clone depth. 0 means a full clone. Part C shows why this is not free."
  type        = number
  const       = true
  default     = 0
}

locals {
  depth_param = var.module_depth > 0 ? "&depth=${var.module_depth}" : ""

  # `//` marks the sub-directory inside the package. Query parameters go AFTER it.
  bucket_module = "git::${var.module_repo}//modules/data-bucket?ref=${var.module_ref}${local.depth_param}"
}

module "bucket" {
  source = local.bucket_module

  name = "ch13-lab3-bucket"
}

output "module_version_tag" {
  description = "Which release of the module actually got installed."
  value       = module.bucket.module_version
}
