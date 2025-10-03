# ===============================================================================
# SECURITY MODULE - MAIN CONFIGURATION
# ===============================================================================
# Módulo responsável por toda a configuração de segurança
# Inclui: Key Vault, Certificados, RBAC, Service Principals
# ===============================================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# ===============================================================================
# DATA SOURCES
# ===============================================================================

data "azurerm_client_config" "current" {}

# ===============================================================================
# LOCAL VALUES
# ===============================================================================

locals {
  # Common naming convention
  name_prefix = var.resource_prefix
  
  # Key Vault name (must be globally unique)
  key_vault_name = "${replace(local.name_prefix, "-", "")}kv${random_id.kv_suffix.hex}"
  
  # Certificate configurations
  certificates = {
    root_ca = {
      name         = "istio-root-ca-cert"
      common_name  = "Istio Root CA"
      organization = "Istio Production"
      country      = "US"
      validity_months = var.certificate_validity_months
      is_ca        = true
      key_size     = 4096
    }
    intermediate_ca = {
      name         = "istio-intermediate-ca-cert"
      common_name  = "Istio Intermediate CA"
      organization = "Istio Production"
      country      = "US"
      validity_months = 12
      is_ca        = true
      key_size     = 2048
    }
    application = {
      name         = "ecommerce-app-cert"
      common_name  = "ecommerce.production.local"
      organization = "Istio Production"
      country      = "US"
      validity_months = 12
      is_ca        = false
      key_size     = 2048
      dns_names    = [
        "ecommerce.production.local",
        "*.ecommerce.production.local",
        "api.ecommerce.production.local",
        "frontend.ecommerce.production.local"
      ]
    }
    gateway_tls = {
      name         = "gateway-tls-cert"
      common_name  = "gateway.production.local"
      organization = "Istio Production"
      country      = "US"
      validity_months = 12
      is_ca        = false
      key_size     = 2048
      dns_names    = [
        "gateway.production.local",
        "*.gateway.production.local",
        "istio-gateway.production.local"
      ]
    }
  }
  
  # Common tags
  common_tags = merge(var.tags, {
    Module = "security"
  })
}

# ===============================================================================
# RANDOM RESOURCES
# ===============================================================================

resource "random_id" "kv_suffix" {
  byte_length = 4
}

resource "random_password" "certificate_passwords" {
  for_each = local.certificates
  
  length  = 32
  special = true
}

# ===============================================================================
# KEY VAULT
# ===============================================================================

resource "azurerm_key_vault" "main" {
  name                = local.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = var.key_vault_sku
  
  # Security features
  enabled_for_deployment          = true
  enabled_for_disk_encryption     = true
  enabled_for_template_deployment = true
  enable_rbac_authorization      = true
  
  # Soft delete and purge protection
  soft_delete_retention_days = var.soft_delete_retention_days
  purge_protection_enabled   = var.enable_purge_protection
  
  # Network access rules
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    
    # Allow access from AKS subnets
    virtual_network_subnet_ids = [
      var.clusters.primary.subnet_id,
      var.clusters.secondary.subnet_id,
      var.clusters.loadtest.subnet_id
    ]
  }
  
  tags = local.common_tags
}

# ===============================================================================
# KEY VAULT ACCESS POLICIES
# ===============================================================================

# Current user/service principal access
resource "azurerm_key_vault_access_policy" "current_user" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = var.tenant_id
  object_id    = data.azurerm_client_config.current.object_id
  
  certificate_permissions = [
    "Backup", "Create", "Delete", "DeleteIssuers", "Get", "GetIssuers",
    "Import", "List", "ListIssuers", "ManageContacts", "ManageIssuers",
    "Purge", "Recover", "Restore", "SetIssuers", "Update"
  ]
  
  key_permissions = [
    "Backup", "Create", "Decrypt", "Delete", "Encrypt", "Get", "Import",
    "List", "Purge", "Recover", "Restore", "Sign", "UnwrapKey", "Update",
    "Verify", "WrapKey"
  ]
  
  secret_permissions = [
    "Backup", "Delete", "Get", "List", "Purge", "Recover", "Restore", "Set"
  ]
}

# AKS Primary Cluster access
resource "azurerm_key_vault_access_policy" "aks_primary" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = var.tenant_id
  object_id    = var.clusters.primary.identity_principal_id
  
  certificate_permissions = [
    "Get", "List"
  ]
  
  key_permissions = [
    "Get", "List"
  ]
  
  secret_permissions = [
    "Get", "List"
  ]
}

# AKS Secondary Cluster access
resource "azurerm_key_vault_access_policy" "aks_secondary" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = var.tenant_id
  object_id    = var.clusters.secondary.identity_principal_id
  
  certificate_permissions = [
    "Get", "List"
  ]
  
  key_permissions = [
    "Get", "List"
  ]
  
  secret_permissions = [
    "Get", "List"
  ]
}

# ===============================================================================
# TLS PRIVATE KEYS
# ===============================================================================

resource "tls_private_key" "certificates" {
  for_each = local.certificates
  
  algorithm = "RSA"
  rsa_bits  = each.value.key_size
}

# ===============================================================================
# TLS CERTIFICATES
# ===============================================================================

# Root CA Certificate
resource "tls_self_signed_cert" "root_ca" {
  private_key_pem = tls_private_key.certificates["root_ca"].private_key_pem
  
  subject {
    common_name  = local.certificates.root_ca.common_name
    organization = local.certificates.root_ca.organization
    country      = local.certificates.root_ca.country
  }
  
  validity_period_hours = local.certificates.root_ca.validity_months * 24 * 30
  is_ca_certificate     = true
  
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
    "crl_signing"
  ]
}

# Intermediate CA Certificate
resource "tls_locally_signed_cert" "intermediate_ca" {
  cert_request_pem   = tls_cert_request.intermediate_ca.cert_request_pem
  ca_private_key_pem = tls_private_key.certificates["root_ca"].private_key_pem
  ca_cert_pem        = tls_self_signed_cert.root_ca.cert_pem
  
  validity_period_hours = local.certificates.intermediate_ca.validity_months * 24 * 30
  is_ca_certificate     = true
  
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
    "crl_signing"
  ]
}

resource "tls_cert_request" "intermediate_ca" {
  private_key_pem = tls_private_key.certificates["intermediate_ca"].private_key_pem
  
  subject {
    common_name  = local.certificates.intermediate_ca.common_name
    organization = local.certificates.intermediate_ca.organization
    country      = local.certificates.intermediate_ca.country
  }
}

# Application Certificate
resource "tls_locally_signed_cert" "application" {
  cert_request_pem   = tls_cert_request.application.cert_request_pem
  ca_private_key_pem = tls_private_key.certificates["intermediate_ca"].private_key_pem
  ca_cert_pem        = tls_locally_signed_cert.intermediate_ca.cert_pem
  
  validity_period_hours = local.certificates.application.validity_months * 24 * 30
  
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth"
  ]
}

resource "tls_cert_request" "application" {
  private_key_pem = tls_private_key.certificates["application"].private_key_pem
  
  subject {
    common_name  = local.certificates.application.common_name
    organization = local.certificates.application.organization
    country      = local.certificates.application.country
  }
  
  dns_names = local.certificates.application.dns_names
}

# Gateway TLS Certificate
resource "tls_locally_signed_cert" "gateway_tls" {
  cert_request_pem   = tls_cert_request.gateway_tls.cert_request_pem
  ca_private_key_pem = tls_private_key.certificates["intermediate_ca"].private_key_pem
  ca_cert_pem        = tls_locally_signed_cert.intermediate_ca.cert_pem
  
  validity_period_hours = local.certificates.gateway_tls.validity_months * 24 * 30
  
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth"
  ]
}

resource "tls_cert_request" "gateway_tls" {
  private_key_pem = tls_private_key.certificates["gateway_tls"].private_key_pem
  
  subject {
    common_name  = local.certificates.gateway_tls.common_name
    organization = local.certificates.gateway_tls.organization
    country      = local.certificates.gateway_tls.country
  }
  
  dns_names = local.certificates.gateway_tls.dns_names
}

# ===============================================================================
# KEY VAULT CERTIFICATES
# ===============================================================================

# Store Root CA Certificate
resource "azurerm_key_vault_certificate" "root_ca" {
  name         = local.certificates.root_ca.name
  key_vault_id = azurerm_key_vault.main.id
  
  certificate {
    contents = base64encode(tls_self_signed_cert.root_ca.cert_pem)
    password = random_password.certificate_passwords["root_ca"].result
  }
  
  certificate_policy {
    issuer_parameters {
      name = "Self"
    }
    
    key_properties {
      exportable = true
      key_size   = local.certificates.root_ca.key_size
      key_type   = "RSA"
      reuse_key  = false
    }
    
    secret_properties {
      content_type = "application/x-pem-file"
    }
  }
  
  tags = merge(local.common_tags, {
    CertificateType = "RootCA"
    Environment     = "production"
  })
  
  depends_on = [azurerm_key_vault_access_policy.current_user]
}

# Store Intermediate CA Certificate
resource "azurerm_key_vault_certificate" "intermediate_ca" {
  name         = local.certificates.intermediate_ca.name
  key_vault_id = azurerm_key_vault.main.id
  
  certificate {
    contents = base64encode(tls_locally_signed_cert.intermediate_ca.cert_pem)
    password = random_password.certificate_passwords["intermediate_ca"].result
  }
  
  certificate_policy {
    issuer_parameters {
      name = "Self"
    }
    
    key_properties {
      exportable = true
      key_size   = local.certificates.intermediate_ca.key_size
      key_type   = "RSA"
      reuse_key  = false
    }
    
    secret_properties {
      content_type = "application/x-pem-file"
    }
  }
  
  tags = merge(local.common_tags, {
    CertificateType = "IntermediateCA"
    Environment     = "production"
  })
  
  depends_on = [azurerm_key_vault_access_policy.current_user]
}

# Store Application Certificate
resource "azurerm_key_vault_certificate" "application" {
  name         = local.certificates.application.name
  key_vault_id = azurerm_key_vault.main.id
  
  certificate {
    contents = base64encode(tls_locally_signed_cert.application.cert_pem)
    password = random_password.certificate_passwords["application"].result
  }
  
  certificate_policy {
    issuer_parameters {
      name = "Self"
    }
    
    key_properties {
      exportable = true
      key_size   = local.certificates.application.key_size
      key_type   = "RSA"
      reuse_key  = false
    }
    
    secret_properties {
      content_type = "application/x-pem-file"
    }
  }
  
  tags = merge(local.common_tags, {
    CertificateType = "Application"
    Environment     = "production"
  })
  
  depends_on = [azurerm_key_vault_access_policy.current_user]
}

# Store Gateway TLS Certificate
resource "azurerm_key_vault_certificate" "gateway_tls" {
  name         = local.certificates.gateway_tls.name
  key_vault_id = azurerm_key_vault.main.id
  
  certificate {
    contents = base64encode(tls_locally_signed_cert.gateway_tls.cert_pem)
    password = random_password.certificate_passwords["gateway_tls"].result
  }
  
  certificate_policy {
    issuer_parameters {
      name = "Self"
    }
    
    key_properties {
      exportable = true
      key_size   = local.certificates.gateway_tls.key_size
      key_type   = "RSA"
      reuse_key  = false
    }
    
    secret_properties {
      content_type = "application/x-pem-file"
    }
  }
  
  tags = merge(local.common_tags, {
    CertificateType = "Gateway"
    Environment     = "production"
  })
  
  depends_on = [azurerm_key_vault_access_policy.current_user]
}

# ===============================================================================
# KEY VAULT SECRETS (Private Keys)
# ===============================================================================

resource "azurerm_key_vault_secret" "private_keys" {
  for_each = local.certificates
  
  name         = "${each.value.name}-private-key"
  value        = tls_private_key.certificates[each.key].private_key_pem
  key_vault_id = azurerm_key_vault.main.id
  
  tags = merge(local.common_tags, {
    SecretType  = "PrivateKey"
    Environment = "production"
  })
  
  depends_on = [azurerm_key_vault_access_policy.current_user]
}

# ===============================================================================
# ADDITIONAL SECRETS
# ===============================================================================

# CosmosDB connection strings (will be populated by CosmosDB module)
resource "azurerm_key_vault_secret" "cosmosdb_connection_string" {
  name         = "cosmosdb-connection-string"
  value        = "placeholder" # Will be updated by CosmosDB module
  key_vault_id = azurerm_key_vault.main.id
  
  tags = merge(local.common_tags, {
    SecretType  = "ConnectionString"
    Service     = "CosmosDB"
    Environment = "production"
  })
  
  depends_on = [azurerm_key_vault_access_policy.current_user]
  
  lifecycle {
    ignore_changes = [value]
  }
}

# Container Registry credentials
resource "azurerm_key_vault_secret" "acr_username" {
  name         = "acr-username"
  value        = "placeholder" # Will be updated by infrastructure module
  key_vault_id = azurerm_key_vault.main.id
  
  tags = merge(local.common_tags, {
    SecretType  = "Credential"
    Service     = "ContainerRegistry"
    Environment = "production"
  })
  
  depends_on = [azurerm_key_vault_access_policy.current_user]
  
  lifecycle {
    ignore_changes = [value]
  }
}

resource "azurerm_key_vault_secret" "acr_password" {
  name         = "acr-password"
  value        = "placeholder" # Will be updated by infrastructure module
  key_vault_id = azurerm_key_vault.main.id
  
  tags = merge(local.common_tags, {
    SecretType  = "Credential"
    Service     = "ContainerRegistry"
    Environment = "production"
  })
  
  depends_on = [azurerm_key_vault_access_policy.current_user]
  
  lifecycle {
    ignore_changes = [value]
  }
}
