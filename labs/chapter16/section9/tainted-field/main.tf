# `taint` is a state write, which is the whole reason -replace replaced it.
# Watch the instance object gain and lose a key, and the serial move each time.
#
#   tflocal apply -auto-approve
#   python -c "import json;d=json.load(open('terraform.tfstate'));print(sorted(d['resources'][0]['instances'][0].keys()), d['serial'])"
#   terraform taint aws_s3_bucket.t      # serial 1 -> 2, instance gains status
#   terraform untaint aws_s3_bucket.t    # serial 2 -> 3, instance loses status
#
# Measured on Terraform 1.15.8:
#
#   before taint: attributes, identity, identity_schema_version, private,
#                 schema_version, sensitive_attributes
#   after taint:  the same plus status, whose value is "tainted"
#   after untaint: status is gone again
resource "aws_s3_bucket" "t" {
  bucket = "ch16-taintstate"
}
