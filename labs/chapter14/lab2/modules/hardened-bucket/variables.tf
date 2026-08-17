variable "name" {
  description = "Name of the bucket. Differs on every use, so it has no default."
  type        = string
}

# v2 of the interface. The four file-related knobs that used to be flat
# variables are now one object, and every attribute the module can supply a
# sensible value for is optional().
variable "retention" {
  description = "How long object history is kept."
  type = object({
    versioned       = optional(bool, true)
    noncurrent_days = optional(number)
  })
  default = {}
}

# v1 of the interface. Still honoured, still warns.
variable "versioning" {
  description = "Whether to keep previous versions of every object."
  type        = bool
  default     = null
  deprecated  = "Set retention = { versioned = ... } instead. This variable is removed in v2.0.0."
}

variable "tags" {
  description = "Tags applied to the bucket."
  type        = map(string)
  default     = {}
}
