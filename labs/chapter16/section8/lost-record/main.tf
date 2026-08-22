# The dangerous shape of a Terraform-side failure: the object was created and
# the state entry was not written. Simulate it, then watch the retry fail.
#
#   tflocal apply -auto-approve                       # bucket created, entry written
#   terraform state rm aws_s3_bucket.dup              # drop the entry, keep the bucket
#   tflocal apply -auto-approve                       # the retry
#
#   Error: creating S3 Bucket (ch16-dup-demo): BucketAlreadyExists
#
# S3 bucket names are globally unique, so the retry is a hard failure. Where the
# provider allocates the identifier instead, the same situation produces a
# second live object and no error at all, which is worse.
#
# The way out is an import block, not another apply. Clean up with
# `awslocal s3 rb s3://ch16-dup-demo` if state no longer tracks it.
resource "aws_s3_bucket" "dup" {
  bucket = "ch16-dup-demo"
}
