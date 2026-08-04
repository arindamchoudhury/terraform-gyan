# Chapter 11 Lab, Part G — dynamic prevent_destroy, OpenTofu only.
#
# Terraform rejects any reference in a lifecycle rule. OpenTofu 1.12 lifted
# that for prevent_destroy alone. The rule is written as a conditional so the
# run proves the expression is evaluated, not merely tolerated.
#
# Terraform 1.15.8 refuses the configuration outright:
#
#   terraform init
#   terraform validate       # Error: Variables not allowed
#                            # Error: Unsuitable value: value must be known
#
# OpenTofu 1.12.4 accepts it, and enforces it per run:
#
#   tofu init
#   tofu validate                        # Success! The configuration is valid.
#   tofu apply -auto-approve
#   tofu destroy -auto-approve           # env = "prod": refused
#   tofu destroy -auto-approve -var env=dev   # destroyed
#
# No provider and no emulator: terraform_data is built in.

terraform {
  required_version = ">= 1.12"
}

variable "env" {
  type    = string
  default = "prod"
}

resource "terraform_data" "db" {
  input = "pretend-database"

  lifecycle {
    prevent_destroy = var.env == "prod" ? true : false
  }
}
