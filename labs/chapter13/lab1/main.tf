# Chapter 13 lab 1 — calling one local module twice.
# Run with tflocal so both calls land on the emulator at :4566.

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

module "raw" {
  source = "./modules/data-bucket"

  name  = "ch13-lab1-raw"
  layer = "raw"

  tags = {
    Retention = "30d"
  }
}

module "curated" {
  source = "./modules/data-bucket"

  name               = "ch13-lab1-curated"
  layer              = "curated"
  versioning_enabled = false
}

# The caller can extend what the module built, because the module exports the
# handle rather than the whole configuration.
resource "aws_s3_object" "readme" {
  bucket  = module.curated.bucket_id
  key     = "README.txt"
  content = "Written by the root module, into a bucket the child module owns.\n"
}
