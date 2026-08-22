# Writing the `moved` block backwards is caught, not silently destructive.
#
# Apply first with the resource named `notes` and no `moved` block, then rename
# the label to `team_notes` and add the block below, which has `from` and `to`
# the wrong way round. Plan:
#
#   Error: Moved object still exists
#   This statement declares a move from aws_s3_bucket.team_notes, but that
#   resource is still declared at main.tf:1,1.
#
# `from` must name an address configuration no longer declares, and after a
# rename that is the old label, not the new one. The destroy-and-recreate the
# block exists to prevent comes from writing no block at all.
resource "aws_s3_bucket" "team_notes" {
  bucket = "ch16-flip"
}

moved {
  from = aws_s3_bucket.team_notes
  to   = aws_s3_bucket.notes
}
