# Same shape as ./mod, except the second attribute is optional with a default.
# That one difference decides whether a caller's typo is caught or absorbed.
variable "cfg" {
  type = object({
    name          = string
    enabled_https = optional(bool, false)
  })
}

output "cfg" {
  value = var.cfg
}
