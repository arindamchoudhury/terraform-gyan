output "bucket_id" {
  description = "ID of the created bucket."
  value       = aws_s3_bucket.site.id
}

output "bucket_arn" {
  description = "ARN, known only after apply."
  value       = aws_s3_bucket.site.arn
}