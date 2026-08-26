# ---------------------------------------------------------------------------
# CA interna self-signed — solo para portfolio/demo.
# En un caso real: CA propia gestionada aparte, o AWS Private CA.
# ---------------------------------------------------------------------------

resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name  = "${var.project_name}-vpn-ca-${var.environment}"
    organization = var.project_name
  }

  validity_period_hours = 87600 # 10 años
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
    "digital_signature",
    "key_encipherment",
  ]
}

# ---------------------------------------------------------------------------
# Certificado de servidor — firmado por la CA de arriba, lo presenta el
# Client VPN endpoint a los clientes que se conectan.
# ---------------------------------------------------------------------------

resource "tls_private_key" "server" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "server" {
  private_key_pem = tls_private_key.server.private_key_pem

  subject {
    common_name  = "${var.project_name}-vpn-server-${var.environment}"
    organization = var.project_name
  }
  dns_names = ["${var.project_name}-vpn-server-${var.environment}.internal"]
}

resource "tls_locally_signed_cert" "server" {
  cert_request_pem  = tls_cert_request.server.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 87600

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "server" {
  private_key       = tls_private_key.server.private_key_pem
  certificate_body  = tls_locally_signed_cert.server.cert_pem
  certificate_chain = tls_self_signed_cert.ca.cert_pem

  tags = {
    Name = "${var.project_name}-vpn-server-cert-${var.environment}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------
# Certificado raíz (la CA misma) importado a ACM — el Client VPN lo usa para
# validar los certificados de cliente firmados por esta CA (mutual auth).
# ---------------------------------------------------------------------------

resource "aws_acm_certificate" "client_root" {
  private_key       = tls_private_key.ca.private_key_pem
  certificate_body  = tls_self_signed_cert.ca.cert_pem

  tags = {
    Name = "${var.project_name}-vpn-client-root-${var.environment}"
  }

  lifecycle {
    create_before_destroy = true
  }
}
