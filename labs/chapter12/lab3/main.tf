# Chapter 12 Lab, Part C — what a dynamic block refuses to generate.
#
# No provider needed. `terraform_data` is built into the CLI, so this part runs
# even with no network and no emulator.
#
#   terraform init
#   terraform validate                      # clean
#   cp main.tf.lifecycle probe.tf
#   terraform validate                      # Unsupported block type
#   cp main.tf.typo probe.tf
#   terraform validate                      # the SAME error, for a typo
#   rm probe.tf

terraform {
  required_version = ">= 1.15"
}

resource "terraform_data" "baseline" {
  input = "a resource with no repeatable nested blocks at all"

  # Legal: a literal lifecycle block. The point of Part C is that the dynamic
  # form of this exact block is not legal.
  lifecycle {
    ignore_changes = [input]
  }
}

output "baseline" {
  value = terraform_data.baseline.output
}
