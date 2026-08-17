variable "name" {
  description = "Name of the bucket. Must be globally unique, so it differs on every use and has no default."
  type        = string
}

variable "versioning" {
  description = "Whether to keep previous versions of every object."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to the bucket."
  type        = map(string)
  default     = {}
}
