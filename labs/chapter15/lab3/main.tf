# Lab 3 — the gcs backend, against the local GCP emulator.
#
# Same exercise as lab 2, different cloud, and the point is how much is the same:
# an empty backend block, a partial configuration in a .tfbackend file, a state
# object under a prefix, and a lock that is a conditional write on an object.
#
# Start the emulator (it is behind a compose profile, so it does not run by
# default), create the bucket, then init:
#
#   docker compose -f labs/docker-compose.yml --profile gcp up -d
#   ./create-bucket.sh
#   terraform init -backend-config=config.gcs.tfbackend

terraform {
  required_version = ">= 1.10"

  backend "gcs" {}
}

variable "label" {
  type    = string
  default = "gcs-backend"
}

resource "terraform_data" "probe" {
  input = var.label
}

output "probe" {
  value = terraform_data.probe.output
}
