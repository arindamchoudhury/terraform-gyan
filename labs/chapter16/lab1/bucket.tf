# Pruned from generated.tf: the bucket name, and the one argument whose value
# differs from the provider's default. `tags_all` is computed — the generator
# emits it, and it must not stay in the configuration.
resource "aws_s3_bucket" "legacy" {
  bucket = "ch16-legacy-notes"

  tags = {
    owner      = "platform-team"
    managed_by = "nobody"
  }
}
