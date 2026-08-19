# Lab 2, step 2 — the configuration whose state moves into S3.
#
# Apply this as-is first, so there is a local state file worth migrating. Then
# copy main.tf.s3 over it and re-init.

terraform {
  required_version = ">= 1.10"
}

variable "label" {
  type    = string
  default = "s3-backend"
}

# Built into Terraform, so this half of the lab needs no provider plugin.
resource "terraform_data" "probe" {
  input = var.label
}

output "probe" {
  value = terraform_data.probe.output
}
