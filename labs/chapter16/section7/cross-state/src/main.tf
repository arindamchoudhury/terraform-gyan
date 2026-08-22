# The legacy split. Apply here, then move one bucket into ../dst's state file
# with the command the chapter shows:
#
#   terraform state mv -state terraform.tfstate -state-out ../dst/terraform.tfstate \
#     aws_s3_bucket.moves aws_s3_bucket.moves
#
# Then plan both sides. This one asks to CREATE the bucket it just handed away,
# because the resource block below is still here — `state mv` moves state and
# leaves configuration alone. Delete the `moves` block and it plans clean.
resource "aws_s3_bucket" "stays" {
  bucket = "ch16-crossmv-stays"
}

resource "aws_s3_bucket" "moves" {
  bucket = "ch16-crossmv-moves"
}
