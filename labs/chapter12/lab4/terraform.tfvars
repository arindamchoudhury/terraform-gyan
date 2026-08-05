# Every one of these passes an explicit null or an undeclared key on purpose.
plain        = null
not_nullable = null

site = {
  name  = "explicit-null"
  index = null
  error = null
}

cfg = {
  name    = "kept"
  extra   = "silently dropped by Terraform"
  another = 5
}

unify = ["a", 1, true]
