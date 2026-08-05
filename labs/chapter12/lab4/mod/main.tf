# A module whose input declares exactly one attribute.
variable "cfg" {
  type = object({ name = string })
}

output "cfg" {
  value = var.cfg
}
