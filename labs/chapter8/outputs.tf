output "policy_arn" {
  value = aws_iam_policy.read_legacy.arn
}

output "resolved_bucket_arn" {
  value = data.aws_s3_bucket.legacy.arn
}