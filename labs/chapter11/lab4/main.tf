# Chapter 11 Lab, Part D — ignore_changes against real out-of-band drift.
#
#   tflocal init
#   tflocal apply -auto-approve
#   tflocal plan                        # empty on emulator 1.6.0+ (older images
#                                       # dropped creation-time tags — see Ch11 Part D)
#   # drift the tag outside Terraform:
#   awslocal s3api put-bucket-tagging --bucket ch11-drift \
#     --tagging 'TagSet=[{Key=owner,Value=platform-team}]'
#   tflocal plan                        # ~ update in-place, reverting to data-team
#   cp main.tf.ignore main.tf
#   tflocal apply -auto-approve         # 0 changed; state keeps platform-team
#   terraform state show aws_s3_bucket.reports

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

resource "aws_s3_bucket" "reports" {
  bucket = "ch11-drift"

  tags = {
    owner = "data-team"
  }
}
