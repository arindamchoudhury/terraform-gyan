# Forgetting a resource means deleting its `resource` block, so anything that
# still references it now references nothing. Validate-only, no apply needed:
#
#   Error: Reference to undeclared resource
#   A managed resource "aws_s3_bucket" "keep" has not been declared in the root
#   module.
#
# The fix is to remove or re-point the reference before the `removed` block
# lands, not after.
removed {
  from = aws_s3_bucket.keep

  lifecycle {
    destroy = false
  }
}

output "bucket_id" {
  value = aws_s3_bucket.keep.id
}
