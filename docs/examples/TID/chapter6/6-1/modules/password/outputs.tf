output "password" {
  value = random_password.new_password.result
  sensitive = true
}