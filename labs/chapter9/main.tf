terraform {
  required_version = ">= 1.15"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 6.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "random_password" "db" {
  length = 20
}

resource "aws_s3_bucket" "notes" {
  bucket = "state-lab-notes"
}

output "db_password" {
  value     = random_password.db.result
  sensitive = true
}
