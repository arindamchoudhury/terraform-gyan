# v1.1.0: the module is now a shim. It creates nothing itself; it calls the two
# new modules so existing consumers keep working with no change to their code.
terraform {
  required_version = ">= 1.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

variable "prefix" {
  description = "Name prefix for both buckets."
  type        = string
}

module "logs" {
  source = "../logs"
  name   = "${var.prefix}-logs"
}

module "assets" {
  source = "../assets"
  name   = "${var.prefix}-assets"
}

output "logs_bucket" {
  value = module.logs.bucket
}

output "assets_bucket" {
  value = module.assets.bucket
}

# The shim's whole job. Terraform reinterprets the two existing objects as if
# they had been created inside the new child modules. Addresses resolve
# relative to THIS module, so the shim names its own children.
moved {
  from = aws_s3_bucket.logs
  to   = module.logs.aws_s3_bucket.this
}

moved {
  from = aws_s3_bucket.assets
  to   = module.assets.aws_s3_bucket.this
}
