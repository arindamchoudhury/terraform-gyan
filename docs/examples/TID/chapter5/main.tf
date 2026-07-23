resource "tls_private_key" "ca_key" { # references no other resource (edge: provider only)
  algorithm = "ED25519"
}

resource "tls_self_signed_cert" "ca_cert" { # depends on ca_key
  private_key_pem   = tls_private_key.ca_key.private_key_pem
  is_ca_certificate = true

  subject {
    common_name  = "dev-ca.example.com"
    organization = "Dev CA"
  }

  validity_period_hours = 24
  allowed_uses = [
    "cert_signing",
    "crl_signing",
    "digital_signature",
  ]
}

resource "tls_private_key" "child_key" { # references no other resource either — one per domain
  # (edges: provider + var.domains, via for_each)
  for_each  = var.domains # set(string) of domains
  algorithm = "ECDSA"
}

resource "tls_cert_request" "child_request" { # CSR per domain, depends on child_key
  for_each        = var.domains
  private_key_pem = tls_private_key.child_key[each.value].private_key_pem

  subject {
    common_name = each.value
  }
}

resource "tls_locally_signed_cert" "child_certificate" { # signed by the CA
  for_each           = var.domains
  cert_request_pem   = tls_cert_request.child_request[each.value].cert_request_pem
  ca_private_key_pem = tls_private_key.ca_key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca_cert.cert_pem

  validity_period_hours = 12
  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
  ]
}