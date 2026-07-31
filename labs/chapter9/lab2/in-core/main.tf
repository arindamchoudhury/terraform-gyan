# Four in-core resources. terraform_data is served by the built-in
# terraform provider, so there is no plugin round trip and the four
# completions usually land inside one state write.
terraform {
  required_version = ">= 1.15"
}

resource "terraform_data" "a" {
  input = "1"
}

resource "terraform_data" "b" {
  input = "2"
}

resource "terraform_data" "c" {
  input = "3"
}

resource "terraform_data" "d" {
  input = "4"
}
