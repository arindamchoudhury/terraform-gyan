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

# A caller still on the v1 interface: it sets the deprecated variable and reads
# the deprecated output. Both still work. Both warn.
module "logs" {
  source = "../../modules/hardened-bucket"

  name       = "ch14-lab2-logs"
  versioning = true
}

output "bucket_id" {
  value = module.logs.bucket_id
}
