resource "aws_s3_bucket" "customer_data" {
  bucket = "ch16-split-customer-data"
}

import {
  to = aws_s3_bucket.customer_data
  id = "ch16-split-customer-data"
}
