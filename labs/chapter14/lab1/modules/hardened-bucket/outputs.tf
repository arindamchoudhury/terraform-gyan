output "name" {
  description = "Name (id) of the bucket."
  type        = string
  value       = aws_s3_bucket.this.id
}

output "arn" {
  description = "ARN of the bucket, for IAM policy documents."
  type        = string
  value       = aws_s3_bucket.this.arn
}

output "versioning_enabled" {
  description = "Whether object versioning is on. A guarantee the caller may rely on."
  type        = bool
  value       = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled"
}
