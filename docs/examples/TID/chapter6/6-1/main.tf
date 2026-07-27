module "my_password" {
  source = "./modules/password"
}

output "password" {
  value     = module.my_password.password
  sensitive = true
}