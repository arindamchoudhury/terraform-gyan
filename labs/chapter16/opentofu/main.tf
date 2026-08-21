# OpenTofu only. `lifecycle { destroy = false }` on the resource itself is
# OpenTofu 1.12's alternative to a `removed` block: `tofu destroy` forgets the
# object instead of deleting it, and exits non-zero unless you pass
# -suppress-forget-errors. Terraform 1.15.8 rejects the argument outright:
# An argument named "destroy" is not expected here.
resource "aws_s3_bucket" "ot" {
  bucket = "ch16-ot-handover"

  lifecycle {
    destroy = false
  }
}
