# ===============================================================================
# TERRAFORM BACKEND CONFIGURATION - REMOTE STATE
# ===============================================================================
# Azure Storage Account for Terraform state with encryption and RBAC
# Configure via environment variables or Azure CLI authentication
# ===============================================================================

terraform {
  backend "azurerm" {
    # Storage account for Terraform state
    # Values should be provided via backend config file or environment variables:
    # - ARM_ACCESS_KEY or Azure CLI authentication
    # - storage_account_name
    # - container_name
    # - key (state file name)
    
    # Example usage:
    # terraform init \
    #   -backend-config="storage_account_name=tfstateXXXXX" \
    #   -backend-config="container_name=tfstate" \
    #   -backend-config="key=istio-aks-dev.tfstate"
    
    # Security features:
    # - Encryption at rest enabled by default
    # - HTTPS only
    # - RBAC via Azure AD
    # - Shared Access Signature (SAS) tokens with expiration
    
    use_azuread_auth = true  # Use Azure AD for authentication (no storage keys)
    use_oidc        = true   # Support GitHub OIDC for CI/CD
  }
}
