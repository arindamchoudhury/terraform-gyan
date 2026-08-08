output "bucket_id" {
  description = "The bucket's name, as the provider reports it."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "The bucket's ARN, for IAM policies written by the caller."
  value       = aws_s3_bucket.this.arn
}
