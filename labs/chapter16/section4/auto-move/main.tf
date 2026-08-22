# Apply this file as written (one bare bucket), then make each edit below and
# plan. Measured on Terraform 1.15.8.
#
# 1. Add `count = 1`, keeping the bucket name. No `moved` block:
#
#      # aws_s3_bucket.a has moved to aws_s3_bucket.a[0]
#      Plan: 0 to add, 0 to change, 0 to destroy.
#
#    Terraform proposes the move itself.
#
# 2. Swap `count` for `for_each = toset(["small"])`, same bucket name, still no
#    `moved` block:
#
#      # aws_s3_bucket.a will be destroyed
#      # aws_s3_bucket.a["small"] will be created
#      Plan: 1 to add, 0 to change, 1 to destroy.
#
#    No auto-move: the key is yours to choose, so the block is not optional.
resource "aws_s3_bucket" "a" {
  bucket = "ch16-automove"
}
