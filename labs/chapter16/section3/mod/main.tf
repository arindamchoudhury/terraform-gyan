variable "suffix" { type = string }

resource "aws_s3_bucket" "one" {
  bucket = "ch16-mod-${var.suffix}-one"
}

resource "aws_s3_bucket" "two" {
  bucket = "ch16-mod-${var.suffix}-two"
}
