# The `import` block's `to` must carry an instance key when the target resource
# uses count or for_each. This configuration is the failing case: plan it and
# Terraform answers
#
#   Error: Invalid import 'to' expression
#   The target resource is using for_each.
#
# Swap for_each for count and the last line reads "using count" instead.
resource "aws_s3_bucket" "shard" {
  for_each = toset(["a", "b"])
  bucket   = "ch16-bare-${each.key}"
}

import {
  to = aws_s3_bucket.shard
  id = "ch16-bare-a"
}
