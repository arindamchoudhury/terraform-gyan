# Demonstrates the leak documented in Chapter 15, section 11: backend
# credentials passed through -backend-config are copied verbatim into
# .terraform/terraform.tfstate and into every saved plan file, even though this
# file — which the plan also embeds — never sees them.
#
# The two values in config.leak.tfbackend are CANARIES, not credentials.

terraform {
  required_version = ">= 1.10"

  backend "s3" {}
}

resource "terraform_data" "probe" {
  input = "leak-canary"
}
