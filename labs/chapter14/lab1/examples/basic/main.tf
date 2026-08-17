terraform {
  required_version = ">= 1.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# The example is a root module, so this is where the provider is configured.
provider "aws" {
  region = "us-east-1"
}

# An example uses the address an external caller would use. Here the module is
# not published, so a relative path is the only address there is - but note the
# rule: in a published module's examples/, this would be the registry address.
module "logs" {
  source = "../../modules/hardened-bucket"

  name = "ch14-lab1-logs"

  tags = {
    Purpose = "book-lab"
  }
}

output "bucket_name" {
  value = module.logs.name
}

output "bucket_arn" {
  value = module.logs.arn
}

output "versioning_enabled" {
  value = module.logs.versioning_enabled
}
