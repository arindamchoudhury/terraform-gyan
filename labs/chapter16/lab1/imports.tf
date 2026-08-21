# Step 2 — the import block on its own. No resource block yet: this is the
# input to `tflocal plan -generate-config-out=generated.tf`.
import {
  to = aws_s3_bucket.legacy
  id = "ch16-legacy-notes"
}
