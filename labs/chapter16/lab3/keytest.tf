resource "aws_s3_bucket" "shard" {
  for_each = toset(["a", "b"])
  bucket   = "ch16-shard-${each.key}"
}

# Re-adopting after `terraform state rm` — the way back in is always an import.
import {
  for_each = toset(["a", "b"])
  to       = aws_s3_bucket.shard[each.key]
  id       = "ch16-shard-${each.key}"
}
