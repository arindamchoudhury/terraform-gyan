# Copy to contrast.tf and plan. Each of these three for_each values is accepted
# by the dynamic block in main.tf and rejected here, one error at a time —
# uncomment them one by one.

resource "aws_s3_bucket" "r" {
  for_each = toset([aws_s3_bucket.b.id]) # known only after apply
  # for_each = toset([sensitive("a")])   # sensitive values cannot be used
  # for_each = toset(["a", null])        # sets must not contain null values
  bucket = "ch12-res-${each.key}"
}
