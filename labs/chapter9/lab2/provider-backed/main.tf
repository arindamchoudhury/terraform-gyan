# Four provider-backed resources. Each one is a real plugin round trip,
# so each completion tends to produce its own state write.
terraform {
  required_version = ">= 1.15"
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

resource "random_password" "a" {
  length = 8
}

resource "random_password" "b" {
  length = 8
}

resource "random_password" "c" {
  length = 8
}

resource "random_password" "d" {
  length = 8
}
