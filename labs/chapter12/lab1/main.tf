# Chapter 12 Lab, Part A — the milestone: one rule list, one nested block per rule.
#
#   tflocal init
#   tflocal apply -auto-approve
#   tflocal state show aws_security_group.app        # three generated ingress blocks
#   tflocal plan -var enable_ssh=true                # the toggle adds a fourth
#   tflocal destroy -auto-approve
#
# Chapter 12 exercise 6 asks you to rewrite this with
# aws_vpc_security_group_ingress_rule + for_each, which is the shape the AWS
# provider now recommends. That answer is deliberately not shipped here.
#
# The variable is a list of objects with optional attributes. The dynamic block
# turns each element into one ingress subblock. Nothing else in the resource
# changes when a caller adds a fourth rule.

terraform {
  required_version = ">= 1.15"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "ingress_rules" {
  description = "Inbound rules. Only `port` is required; the rest have defaults."

  type = list(object({
    port        = number
    description = optional(string, "Managed by Terraform")
    protocol    = optional(string, "tcp")
    cidr_blocks = optional(list(string), ["0.0.0.0/0"])
  }))

  default = [
    { port = 443, description = "HTTPS from anywhere" },
    { port = 80, description = "HTTP from anywhere" },
    { port = 5432, description = "Postgres from the VPC", cidr_blocks = ["10.0.0.0/8"] },
  ]
}

variable "enable_ssh" {
  description = "Whether to open port 22. Demonstrates the zero-or-one toggle."
  type        = bool
  default     = false
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "app" {
  name        = "ch12-app"
  description = "Rules generated from a typed list of objects"
  vpc_id      = data.aws_vpc.default.id

  # One generated block per element of the list.
  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      description = ingress.value.description
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  # The zero-or-one toggle. The element's value is never read, so it can be
  # anything; only the length of the collection matters.
  dynamic "ingress" {
    for_each = var.enable_ssh ? [1] : []
    content {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    }
  }

  # A dynamic block and a literal block of the same type coexist.
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "ingress_ports" {
  description = "Proves one block was generated per rule."
  value       = sort([for r in aws_security_group.app.ingress : tostring(r.from_port)])
}
