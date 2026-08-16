# Section 9's measurement: a registry example is itself a callable module.
#
#   terraform get
#
# installs the whole ec2-instance package, reads the module from
# examples/complete, and resolves that example's twelve `../../` calls to the
# package root. `terraform get` is enough — no provider install, no AWS.
#
# Measured on Terraform 1.15.8, 2026-08-16: the example's own `~>` constraints
# pulled vpc 6.6.1 and security-group 5.3.1, neither named below.

terraform {
  required_version = ">= 1.15"
}

module "ec2_instance_example_complete" {
  source  = "terraform-aws-modules/ec2-instance/aws//examples/complete"
  version = "6.4.0"
}
