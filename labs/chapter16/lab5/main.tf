resource "aws_s3_bucket" "site" {
  bucket = "ch16-drift-site"

  tags = {
    owner = "oncall-hotfix"
  }
}
