resource "aws_s3_bucket" "app_logs" {
  bucket = "ch16-split-app-logs"
}

# Step 3 — the resource block is replaced by a removed block. `destroy = false`
# is what keeps the bucket alive while it leaves this state file.
removed {
  from = aws_s3_bucket.customer_data

  lifecycle {
    destroy = false
  }
}
