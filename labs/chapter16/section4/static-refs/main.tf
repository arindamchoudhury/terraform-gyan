# `from` and `to` take references, not strings, and not anything computed.
# Two failing forms, both caught by `tflocal validate`:
#
#   from = "aws_s3_bucket.a"        →  Error: Invalid expression
#                                      A single static variable reference is required...
#
#   for_each = toset(["x", "y"])    →  Error: Unsupported argument
#   from     = aws_s3_bucket.a[each.key]  An argument named "for_each" is not expected here.
#
# So a multi-instance migration needs one block written out per instance, which
# is what makes it different from `import`, where `to` can be driven by for_each.
resource "aws_s3_bucket" "b" {
  bucket = "ch16-refs"
}

moved {
  from = "aws_s3_bucket.a"
  to   = aws_s3_bucket.b
}
