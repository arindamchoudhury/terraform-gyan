# The old and new resource never coexist. Planning this configuration fails
# before any plan is produced, because `from` is still declared:
#
#   Error: Moved object still exists
#   This statement declares a move from aws_s3_bucket.single, but that resource
#   is still declared at main.tf:9,1.
#
# The fix is to delete the `single` block: the rename IS the edit to the label.
resource "aws_s3_bucket" "single" {
  bucket = "ch16-both-single"
}

resource "aws_s3_bucket" "other" {
  bucket = "ch16-both-other"
}

moved {
  from = aws_s3_bucket.single
  to   = aws_s3_bucket.other
}
