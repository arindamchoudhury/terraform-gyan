data "null_data_source" "values" {
  
}

resource "random_password" "new_password" {
  length = 12
}

check "password_strength" {
  assert {
    condition = length(random_password.new_password.result) >= 12
    error_message = "random_password.new_password.id should return a password at least"
  }
}