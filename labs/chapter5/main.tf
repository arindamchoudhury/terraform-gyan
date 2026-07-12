resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "site" {
  bucket = "site-${random_id.suffix.hex}"
}

resource "aws_s3_object" "index" {
  bucket  = aws_s3_bucket.site.id
  key     = "index.html"
  content = "hello from terraform"
}