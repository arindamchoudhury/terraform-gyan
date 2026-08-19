# The configuration the pipeline manages. terraform_data keeps the lab about
# state and CI rather than about a provider.

terraform {
  required_version = ">= 1.10"

  backend "s3" {}
}

variable "label" {
  type    = string
  default = "managed-from-gitlab-ci"
}

resource "terraform_data" "probe" {
  input = var.label
}

output "probe" {
  value = terraform_data.probe.output
}
