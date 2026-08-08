# Deliberately only ONE of the child module's outputs is re-exported here.
# Part C of the lab uses the gap: module.raw.bucket_arn is readable in
# configuration but invisible to `terraform output` until a root output names it.

output "curated_bucket_arn" {
  description = "ARN of the curated bucket, re-exported from the child module."
  value       = module.curated.bucket_arn
}
