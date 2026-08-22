# `removed` refuses an instance key, so a count or for_each resource is
# forgotten in full or not at all. No apply needed: this fails at validate.
#
# The resource block is commented out on purpose, because `from` must name an
# address configuration no longer declares.
#
# resource "aws_s3_bucket" "shard" {
#   for_each = toset(["a", "b"])
#   bucket   = "ch16-removedkey-${each.key}"
# }

removed {
  from = aws_s3_bucket.shard["a"]

  lifecycle {
    destroy = false
  }
}
