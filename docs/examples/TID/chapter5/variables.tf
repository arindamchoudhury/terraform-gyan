variable "domains" {
  type        = set(string)
  description = "Domains to issue a leaf cert for — one child_key/request/cert per entry."
  default     = ["alice.example.com", "bob.example.com", "charlie.example.com"]
}
