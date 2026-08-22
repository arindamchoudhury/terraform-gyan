# Drift does not stop at the resource. An output computed from a drifted
# attribute is rewritten by the same refresh-only apply, and anything reading
# this state through terraform_remote_state then reads the drift.
#
#   tflocal apply -auto-approve
#   awslocal s3api put-bucket-tagging --bucket ch16-outdrift \
#     --tagging 'TagSet=[{Key=owner,Value=oncall-hotfix}]'
#   tflocal apply -refresh-only -auto-approve
#
#   Changes to Outputs:
#     ~ owner_tag = "platform-team" -> "oncall-hotfix"
#   Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
#
# Three zeroes, and terraform output now returns the hotfix value.
resource "aws_s3_bucket" "site" {
  bucket = "ch16-outdrift"

  tags = {
    owner = "platform-team"
  }
}

output "owner_tag" {
  value = aws_s3_bucket.site.tags["owner"]
}
