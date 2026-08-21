resource "aws_s3_bucket" "handover" {
  bucket = "ch16-handover"
}

import {
  to = aws_s3_bucket.handover
  id = "ch16-handover"
}
