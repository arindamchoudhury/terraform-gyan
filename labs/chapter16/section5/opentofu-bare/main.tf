# OpenTofu only — run everything here with TF_CMD=tofu.
#
# The same bare `removed` block that destroys under Terraform forgets under
# OpenTofu, because its default is the opposite. Apply this file first, then
# replace it with the block below and plan.
#
#   removed {
#     from = aws_s3_bucket.gone
#   }
#
# OpenTofu 1.12.5 answers:
#
#   Plan: 0 to add, 0 to change, 0 to destroy, 1 to forget.
#
#   Warning: Resource will be removed from the state
#   Warning: Missing lifecycle from the removed block
#
# Terraform 1.15.8 given the identical block plans `1 to destroy` and warns
# about nothing. The source says why: OpenTofu's internal/configs/removed.go
# initialises Destroy to false and tracks whether lifecycle set it, where
# Terraform's sets Destroy = true before it looks for a lifecycle block.
resource "aws_s3_bucket" "gone" {
  bucket = "ch16-otremoved"
}
