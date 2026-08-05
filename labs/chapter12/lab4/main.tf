# Chapter 12 Lab, Part D — the type-constraint boundary.
#
# No provider needed.
#
#   terraform init
#   terraform apply -auto-approve       # read the three outputs
#   terraform validate                  # "Success!" -- note what it does NOT say
#   tofu init && tofu validate          # OpenTofu warns about the dropped key
#
# Every value below is supplied by terraform.tfvars, so each output shows what
# the constraint did to the caller's input on the way in.

terraform {
  required_version = ">= 1.15"
}

# --- the optional() / nullable asymmetry ------------------------------------
# Both say "default". Only one of them survives an explicit null.

variable "plain" {
  description = "A variable default. nullable is true by default."
  type        = string
  default     = "fallback"
}

variable "not_nullable" {
  description = "The same default, opted out of accepting null."
  type        = string
  default     = "fallback"
  nullable    = false
}

variable "site" {
  description = "An optional() default, which behaves like nullable = false and cannot opt out."
  type = object({
    name  = string
    index = optional(string, "index.html")
    error = optional(string) # no default -> a typed null
  })
}

# --- what an object constraint silently discards -----------------------------

variable "cfg" {
  description = "Declares one attribute. The tfvars file supplies three."
  type        = object({ name = string })
}

# --- unification under list(any) ---------------------------------------------

variable "unify" {
  description = "One element type has to be found for all three values."
  type        = list(any)
}

output "plain" {
  description = "Explicit null is kept. The default does not apply."
  value       = var.plain
}

output "not_nullable" {
  description = "Explicit null is replaced by the default."
  value       = var.not_nullable
}

output "site" {
  description = "index gets its default even though the caller passed null; error stays a typed null."
  value       = var.site
}

output "cfg" {
  description = "The two undeclared attributes are gone."
  value       = var.cfg
}

output "unify" {
  description = "A list of three different types became a list(string)."
  value       = var.unify
}

# --- the same drop, at a module boundary -------------------------------------
# This is the realistic shape of the mistake: a caller passes an attribute the
# module never declared. Terraform accepts it silently. OpenTofu warns.

module "typo" {
  source = "./mod"

  cfg = {
    name         = "kept"
    enable_https = true # the module declares no such attribute
  }
}

output "module_cfg" {
  description = "The undeclared attribute never reaches the module."
  value       = module.typo.cfg
}

# --- what decides whether the typo is caught ---------------------------------
# ./mod-optional declares enabled_https as optional(bool, false). The caller
# misspells it. The attribute is discarded exactly as above, but now nothing is
# missing, so the default fills the hole and the apply succeeds with the wrong
# value. Swap the source to ./mod-required (see main.tf.required) to see the
# same typo rejected by name instead.

module "typo_optional" {
  source = "./mod-optional"

  cfg = {
    name          = "a"
    enable_https  = true # typo: the module declares enabled_https
  }
}

output "typo_optional" {
  description = "enabled_https is false, not true. The caller's intent was dropped."
  value       = module.typo_optional.cfg
}
