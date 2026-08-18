terraform {
  required_version = ">= 1.15"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # A root module sets a ceiling as well as a floor. The module this calls
      # says ">= 5.0", because a shared module must not cap its callers.
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# The consumer's code. It does not change across the whole lab - that is the
# point of the exercise.
module "storage" {
  source = "../../modules/storage"

  prefix = "ch14-lab3"
}

output "logs_bucket" {
  value = module.storage.logs_bucket
}

output "assets_bucket" {
  value = module.storage.assets_bucket
}
