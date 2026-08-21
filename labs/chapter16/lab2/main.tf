resource "aws_s3_bucket" "team_notes" {
  bucket = "ch16-moved-notes"
}

# Migrated from `count` to `for_each`. The bucket names are unchanged — only
# the instance keys are, from positions to meaningful names.
resource "aws_s3_bucket" "archive" {
  for_each = { cold = 0, warm = 1 }
  bucket   = "ch16-moved-archive-${each.value}"
}

moved {
  from = aws_s3_bucket.notes
  to   = aws_s3_bucket.team_notes
}

moved {
  from = aws_s3_bucket.archive[0]
  to   = aws_s3_bucket.archive["cold"]
}

moved {
  from = aws_s3_bucket.archive[1]
  to   = aws_s3_bucket.archive["warm"]
}
