# Two independent buckets, which is enough to see both targeting warnings and
# the work a targeted run defers.
#
#   tflocal apply -auto-approve -target aws_s3_bucket.one
#
# Plan time:  Warning: Resource targeting is in effect
# Apply time: Warning: Applied changes may be incomplete
#             ... Run the following command to verify that no other changes
#             are pending: terraform plan
#
# Then `tflocal plan` reports `aws_s3_bucket.two will be created`, 1 to add:
# the deferred half, waiting. Finish with an untargeted apply, or destroy.
resource "aws_s3_bucket" "one" {
  bucket = "ch16-targetwarn-one"
}

resource "aws_s3_bucket" "two" {
  bucket = "ch16-targetwarn-two"
}
