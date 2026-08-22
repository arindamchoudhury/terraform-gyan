# A `moved` block with no instance key on either side moves every instance of a
# multi-instance resource and keeps each key. Apply this with the resource named
# `old`, then rename it to `new` and add the block below:
#
#   # aws_s3_bucket.old["a"] has moved to aws_s3_bucket.new["a"]
#   # aws_s3_bucket.old["b"] has moved to aws_s3_bucket.new["b"]
#   Plan: 0 to add, 0 to change, 0 to destroy.
resource "aws_s3_bucket" "new" {
  for_each = toset(["a", "b"])
  bucket   = "ch16-movedbare-${each.key}"
}

moved {
  from = aws_s3_bucket.old
  to   = aws_s3_bucket.new
}
