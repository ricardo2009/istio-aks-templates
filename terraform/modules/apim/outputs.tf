# ===============================================================================
# AZURE API MANAGEMENT MODULE - OUTPUTS
# ===============================================================================

# APIM Instance
output "id" {
  description = "ID da instância APIM"
  value       = azurerm_api_management.main.id
}

output "name" {
  description = "Nome da instância APIM"
  value       = azurerm_api_management.main.name
}

output "gateway_url" {
  description = "URL do gateway APIM"
  value       = azurerm_api_management.main.gateway_url
}

output "portal_url" {
  description = "URL do portal do desenvolvedor"
  value       = azurerm_api_management.main.portal_url
}

output "management_api_url" {
  description = "URL da API de gerenciamento"
  value       = azurerm_api_management.main.management_api_url
}

output "scm_url" {
  description = "URL do SCM"
  value       = azurerm_api_management.main.scm_url
}

# Network Information
output "public_ip_addresses" {
  description = "Endereços IP públicos do APIM"
  value       = azurerm_api_management.main.public_ip_addresses
}

output "private_ip_addresses" {
  description = "Endereços IP privados do APIM"
  value       = azurerm_api_management.main.private_ip_addresses
}

output "public_ip_address_id" {
  description = "ID do endereço IP público dedicado"
  value       = azurerm_public_ip.apim.id
}

output "public_ip_address" {
  description = "Endereço IP público dedicado"
  value       = azurerm_public_ip.apim.ip_address
}

output "fqdn" {
  description = "FQDN do endereço IP público"
  value       = azurerm_public_ip.apim.fqdn
}

# Identity Information
output "identity" {
  description = "Informações da identidade gerenciada do APIM"
  value = {
    principal_id = azurerm_api_management.main.identity[0].principal_id
    tenant_id    = azurerm_api_management.main.identity[0].tenant_id
  }
}

# APIs Information
output "configured_apis" {
  description = "APIs configuradas no APIM"
  value = {
    for api_key, api in azurerm_api_management_api.apis : api_key => {
      id           = api.id
      name         = api.name
      display_name = api.display_name
      path         = api.path
      service_url  = api.service_url
    }
  }
}

# Products Information
output "configured_products" {
  description = "Produtos configurados no APIM"
  value = {
    for product_key, product in azurerm_api_management_product.products : product_key => {
      id                    = product.id
      product_id           = product.product_id
      display_name         = product.display_name
      published            = product.published
      subscription_required = product.subscription_required
      subscriptions_limit  = product.subscriptions_limit
    }
  }
}

# Application Insights
output "application_insights" {
  description = "Informações do Application Insights"
  value = {
    id                   = azurerm_application_insights.apim.id
    name                 = azurerm_application_insights.apim.name
    instrumentation_key  = azurerm_application_insights.apim.instrumentation_key
    connection_string    = azurerm_application_insights.apim.connection_string
  }
  sensitive = true
}

# API Endpoints
output "api_endpoints" {
  description = "Endpoints das APIs configuradas"
  value = {
    ecommerce_api = "${azurerm_api_management.main.gateway_url}/api/v1"
    user_api      = "${azurerm_api_management.main.gateway_url}/users/v1"
    payment_api   = "${azurerm_api_management.main.gateway_url}/payments/v1"
  }
}

# Subscription Keys (for testing)
output "subscription_keys_info" {
  description = "Informações sobre chaves de subscrição (para documentação)"
  value = {
    note = "Use Azure Portal ou Azure CLI para obter chaves de subscrição"
    commands = {
      list_subscriptions = "az apim subscription list --service-name ${azurerm_api_management.main.name} --resource-group ${var.resource_group_name}"
      get_keys          = "az apim subscription show --service-name ${azurerm_api_management.main.name} --resource-group ${var.resource_group_name} --subscription-id <subscription-id>"
    }
  }
}

# Health Check Endpoints
output "health_endpoints" {
  description = "Endpoints para verificação de saúde"
  value = {
    apim_status = "${azurerm_api_management.main.gateway_url}/status-0123456789abcdef"
    echo_api    = "${azurerm_api_management.main.gateway_url}/echo/resource"
  }
}

# Developer Portal Information
output "developer_portal_info" {
  description = "Informações do portal do desenvolvedor"
  value = {
    url = azurerm_api_management.main.portal_url
    note = "Configure authentication and customize the portal via Azure Portal"
  }
}

# Monitoring and Logging
output "monitoring_info" {
  description = "Informações de monitoramento e logging"
  value = {
    application_insights_id = azurerm_application_insights.apim.id
    diagnostic_settings = {
      note = "Diagnostic settings configured for Application Insights integration"
      sampling_percentage = 100.0
      log_client_ip      = true
    }
  }
}
