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

output "bucket_id" {
  description = "Name (id) of the bucket."
  type        = string
  value       = aws_s3_bucket.this.id
  deprecated  = "Use the name output instead. This output is removed in v2.0.0."
}
