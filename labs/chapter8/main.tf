data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_s3_bucket" "legacy" {
    bucket = "legacy-data-bucket"
}

data "aws_iam_policy_document" "read_legacy" {
  statement {
    sid = "ReadLegacyBucket"
    actions = [ "s3:GetObject", "s3:ListBucket" ]
    resources = [
        data.aws_s3_bucket.legacy.arn,
        "${data.aws_s3_bucket.legacy.arn}/*"
    ]
  }
}


resource "aws_iam_policy" "read_legacy" {
  name = "read-legacy-${data.aws_region.current.region}"
  policy = data.aws_iam_policy_document.read_legacy.json

  tags = {
    Account = data.aws_caller_identity.current.account_id
  }
}