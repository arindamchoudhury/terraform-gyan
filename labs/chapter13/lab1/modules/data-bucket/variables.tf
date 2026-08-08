variable "name" {
  description = "Bucket name. Must be globally unique on real AWS."
  type        = string
}

variable "layer" {
  description = "Which layer of the data platform this bucket serves."
  type        = string

  validation {
    condition     = contains(["raw", "curated", "published"], var.layer)
    error_message = "layer must be one of: raw, curated, published."
  }
}

variable "versioning_enabled" {
  description = "Keep old object versions. Off costs less; on survives a bad overwrite."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Extra tags merged onto the bucket."
  type        = map(string)
  default     = {}
}
