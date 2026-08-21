# Section 1's walkthrough, at its end state.
#
# Stage 1 was this file with only aws_s3_bucket.notes.
# Stage 2 added aws_s3_bucket.archive using `count = 2`.
# Stage 3 is what you see here: the same two archive buckets re-keyed by name.
#
# See README.md in this directory for the two earlier stages verbatim.

resource "aws_s3_bucket" "notes" {
  bucket = "ch16-moved-notes"
}

# Migrated from `count` to `for_each`. The bucket names are unchanged, so both
# objects survive; only the instance keys move, from positions to names.
resource "aws_s3_bucket" "archive" {
  for_each = { cold = 0, warm = 1 }
  bucket   = "ch16-moved-archive-${each.value}"
}

moved {
  from = aws_s3_bucket.archive[0]
  to   = aws_s3_bucket.archive["cold"]
}

moved {
  from = aws_s3_bucket.archive[1]
  to   = aws_s3_bucket.archive["warm"]
}
