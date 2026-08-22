# A tainted object does not stop at itself. Apply, then taint the bucket and
# plan: the versioning resource is replaced too.
#
#   tflocal apply -auto-approve
#   terraform taint aws_s3_bucket.upstream
#   tflocal plan
#
#   # aws_s3_bucket.upstream is tainted, so must be replaced
#   # aws_s3_bucket_versioning.downstream must be replaced
#   Plan: 2 to add, 0 to change, 2 to destroy.
#
# The reason is ordinary, not a special taint rule. Read the downstream block:
#
#   ~ bucket = "ch16-taintdown" -> (known after apply) # forces replacement
#
# The upstream id cannot be known while it is being replaced, and `bucket` is a
# forced-new argument, so the unknown propagates. Undo with
# `terraform untaint aws_s3_bucket.upstream`.
resource "aws_s3_bucket" "upstream" {
  bucket = "ch16-taintdown"
}

resource "aws_s3_bucket_versioning" "downstream" {
  bucket = aws_s3_bucket.upstream.id

  versioning_configuration {
    status = "Enabled"
  }
}
