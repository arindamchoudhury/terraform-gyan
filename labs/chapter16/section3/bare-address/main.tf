# Two instances of one resource, so a bare address `aws_s3_bucket.shard` names a
# set of two rather than a single object. The four commands in section 3's table
# are each given exactly that address, and each answers differently.
#
# Bucket names are unique to this directory so it can be applied alongside the
# chapter's other labs.
resource "aws_s3_bucket" "shard" {
  for_each = toset(["a", "b"])
  bucket   = "ch16-parsers-${each.key}"
}
