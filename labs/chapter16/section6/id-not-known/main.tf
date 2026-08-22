# `id` has to be resolvable while Terraform is planning, so another managed
# resource's attribute is not allowed: it is `(known after apply)`. Plan-only,
# nothing is created:
#
#   Error: Invalid import id argument
#
#     on main.tf line 26, in import:
#     26:   id = aws_s3_bucket.source.id
#
#   The import block "id" argument depends on resource attributes that cannot be
#   determined until apply, so Terraform cannot plan to import this resource.
#
# A variable, a local or each.value are all fine, because all three resolve
# before the plan is built. internal/terraform/eval_import.go carries the same
# diagnostic for `identity`.
resource "aws_s3_bucket" "source" {
  bucket = "ch16-idknown-source"
}

resource "aws_s3_bucket" "adopted" {
  bucket = "ch16-idknown-adopted"
}

import {
  to = aws_s3_bucket.adopted
  id = aws_s3_bucket.source.id
}
