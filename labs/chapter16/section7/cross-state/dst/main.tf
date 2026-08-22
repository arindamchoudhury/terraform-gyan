# The destination of the legacy split. The resource block is already here, so
# after the move this side plans clean. Delete it to see the other half of the
# same trap: state holding an object no configuration declares, which is
# section 1's destroy case.
#
# Do not apply this directory before the move. The bucket belongs to ../src
# until `state mv` hands it over.
resource "aws_s3_bucket" "moves" {
  bucket = "ch16-crossmv-moves"
}
