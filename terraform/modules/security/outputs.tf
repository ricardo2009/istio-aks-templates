# ===============================================================================
# SECURITY MODULE - OUTPUTS
# ===============================================================================

# Key Vault
output "key_vault_id" {
  description = "ID do Key Vault"
  value       = azurerm_key_vault.main.id
}

output "key_vault_name" {
  description = "Nome do Key Vault"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "URI do Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

# Certificates
output "root_ca_certificate_name" {
  description = "Nome do certificado Root CA no Key Vault"
  value       = azurerm_key_vault_certificate.root_ca.name
}

output "intermediate_ca_certificate_name" {
  description = "Nome do certificado Intermediate CA no Key Vault"
  value       = azurerm_key_vault_certificate.intermediate_ca.name
}

output "application_certificate_name" {
  description = "Nome do certificado da aplicação no Key Vault"
  value       = azurerm_key_vault_certificate.application.name
}

output "gateway_tls_certificate_name" {
  description = "Nome do certificado TLS do gateway no Key Vault"
  value       = azurerm_key_vault_certificate.gateway_tls.name
}

# Certificate IDs
output "certificate_ids" {
  description = "IDs dos certificados no Key Vault"
  value = {
    root_ca      = azurerm_key_vault_certificate.root_ca.id
    intermediate = azurerm_key_vault_certificate.intermediate_ca.id
    application  = azurerm_key_vault_certificate.application.id
    gateway_tls  = azurerm_key_vault_certificate.gateway_tls.id
  }
}

# Certificate URIs
output "certificate_uris" {
  description = "URIs dos certificados no Key Vault"
  value = {
    root_ca      = azurerm_key_vault_certificate.root_ca.secret_id
    intermediate = azurerm_key_vault_certificate.intermediate_ca.secret_id
    application  = azurerm_key_vault_certificate.application.secret_id
    gateway_tls  = azurerm_key_vault_certificate.gateway_tls.secret_id
  }
}

# Private Key Secret Names
output "private_key_secret_names" {
  description = "Nomes dos secrets das chaves privadas no Key Vault"
  value = {
    for cert_name, secret in azurerm_key_vault_secret.private_keys : cert_name => secret.name
  }
}

# Certificate Data (for Kubernetes secrets)
output "certificate_data" {
  description = "Dados dos certificados para uso em Kubernetes"
  value = {
    root_ca = {
      cert_pem = tls_self_signed_cert.root_ca.cert_pem
      key_pem  = tls_private_key.certificates["root_ca"].private_key_pem
    }
    intermediate_ca = {
      cert_pem = tls_locally_signed_cert.intermediate_ca.cert_pem
      key_pem  = tls_private_key.certificates["intermediate_ca"].private_key_pem
    }
    application = {
      cert_pem = tls_locally_signed_cert.application.cert_pem
      key_pem  = tls_private_key.certificates["application"].private_key_pem
    }
    gateway_tls = {
      cert_pem = tls_locally_signed_cert.gateway_tls.cert_pem
      key_pem  = tls_private_key.certificates["gateway_tls"].private_key_pem
    }
  }
  sensitive = true
}

# Certificate Chain
output "certificate_chain" {
  description = "Cadeia completa de certificados"
  value = {
    full_chain = "${tls_locally_signed_cert.application.cert_pem}${tls_locally_signed_cert.intermediate_ca.cert_pem}${tls_self_signed_cert.root_ca.cert_pem}"
    app_chain  = "${tls_locally_signed_cert.application.cert_pem}${tls_locally_signed_cert.intermediate_ca.cert_pem}"
  }
  sensitive = true
}

# Secret IDs for external reference
output "secret_ids" {
  description = "IDs dos secrets no Key Vault"
  value = {
    cosmosdb_connection_string = azurerm_key_vault_secret.cosmosdb_connection_string.id
    acr_username              = azurerm_key_vault_secret.acr_username.id
    acr_password              = azurerm_key_vault_secret.acr_password.id
  }
}

# Access Policy Information
output "access_policies" {
  description = "Informações das políticas de acesso configuradas"
  value = {
    current_user = azurerm_key_vault_access_policy.current_user.object_id
    aks_primary  = azurerm_key_vault_access_policy.aks_primary.object_id
    aks_secondary = azurerm_key_vault_access_policy.aks_secondary.object_id
  }
}
