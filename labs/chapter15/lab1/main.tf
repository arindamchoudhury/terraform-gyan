# Lab 1 — the local backend, stated explicitly.
#
# Every earlier lab used the local backend without saying so: with no `backend`
# block at all, Terraform writes ./terraform.tfstate. This configuration names
# it, and moves the file, which is the smallest possible demonstration that a
# backend is a choice rather than a default.
#
# No emulator, no credentials, no network.

terraform {
  required_version = ">= 1.10"

  backend "local" {
    # Relative to the working directory. The directory is created for you.
    path = "state/dev.tfstate"
  }
}

variable "label" {
  type        = string
  description = "Value to store, so the state has something in it worth looking at."
  default     = "local-backend"
}

# terraform_data is built into Terraform, so this lab needs no provider plugin
# and no registry download.
resource "terraform_data" "probe" {
  input = var.label
}

output "probe" {
  value = terraform_data.probe.output
}
