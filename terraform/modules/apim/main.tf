# ===============================================================================
# AZURE API MANAGEMENT MODULE - MAIN CONFIGURATION
# ===============================================================================
# Módulo responsável por configurar Azure API Management
# Inclui: APIM Instance, APIs, Policies, Products, Subscriptions
# ===============================================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# ===============================================================================
# LOCAL VALUES
# ===============================================================================

locals {
  # Common naming convention
  name_prefix = var.resource_prefix
  apim_name   = "${local.name_prefix}-apim"
  
  # API configurations
  apis = {
    ecommerce_api = {
      name         = "ecommerce-api"
      display_name = "E-commerce API"
      description  = "Main e-commerce application API"
      path         = "api/v1"
      protocols    = ["https"]
      backend_url  = "https://${var.cluster_endpoints.primary}/api/v1"
      operations = {
        get_products = {
          display_name = "Get Products"
          method       = "GET"
          url_template = "/products"
          description  = "Retrieve all products"
        }
        get_product = {
          display_name = "Get Product"
          method       = "GET"
          url_template = "/products/{id}"
          description  = "Retrieve a specific product"
        }
        create_order = {
          display_name = "Create Order"
          method       = "POST"
          url_template = "/orders"
          description  = "Create a new order"
        }
        get_orders = {
          display_name = "Get Orders"
          method       = "GET"
          url_template = "/orders"
          description  = "Retrieve user orders"
        }
      }
    }
    user_api = {
      name         = "user-api"
      display_name = "User Management API"
      description  = "User authentication and profile management"
      path         = "users/v1"
      protocols    = ["https"]
      backend_url  = "https://${var.cluster_endpoints.primary}/users/v1"
      operations = {
        login = {
          display_name = "User Login"
          method       = "POST"
          url_template = "/auth/login"
          description  = "Authenticate user"
        }
        register = {
          display_name = "User Registration"
          method       = "POST"
          url_template = "/auth/register"
          description  = "Register new user"
        }
        get_profile = {
          display_name = "Get Profile"
          method       = "GET"
          url_template = "/profile"
          description  = "Get user profile"
        }
      }
    }
    payment_api = {
      name         = "payment-api"
      display_name = "Payment Processing API"
      description  = "Payment processing and transaction management"
      path         = "payments/v1"
      protocols    = ["https"]
      backend_url  = "https://${var.cluster_endpoints.secondary}/payments/v1"
      operations = {
        process_payment = {
          display_name = "Process Payment"
          method       = "POST"
          url_template = "/process"
          description  = "Process payment transaction"
        }
        get_payment_status = {
          display_name = "Get Payment Status"
          method       = "GET"
          url_template = "/status/{transactionId}"
          description  = "Get payment transaction status"
        }
      }
    }
  }
  
  # Products configuration
  products = {
    starter = {
      name         = "starter"
      display_name = "Starter Plan"
      description  = "Basic API access with rate limiting"
      published    = true
      approval_required = false
      subscription_required = true
      subscriptions_limit = 1000
    }
    premium = {
      name         = "premium"
      display_name = "Premium Plan"
      description  = "Full API access with higher rate limits"
      published    = true
      approval_required = true
      subscription_required = true
      subscriptions_limit = 100
    }
  }
  
  # Common tags
  common_tags = merge(var.tags, {
    Module = "apim"
  })
}

# ===============================================================================
# RANDOM RESOURCES
# ===============================================================================

resource "random_id" "apim_suffix" {
  byte_length = 4
}

# ===============================================================================
# PUBLIC IP FOR APIM
# ===============================================================================

resource "azurerm_public_ip" "apim" {
  name                = "${local.apim_name}-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                = "Standard"
  domain_name_label   = "${local.name_prefix}-apim-${random_id.apim_suffix.hex}"
  
  tags = local.common_tags
}

# ===============================================================================
# API MANAGEMENT INSTANCE
# ===============================================================================

resource "azurerm_api_management" "main" {
  name                = local.apim_name
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name           = var.sku_name
  
  # Network configuration
  virtual_network_type = var.virtual_network_type
  
  dynamic "virtual_network_configuration" {
    for_each = var.virtual_network_type != "None" ? [1] : []
    content {
      subnet_id = var.subnet_id
    }
  }
  
  # Identity configuration
  identity {
    type = "SystemAssigned"
  }
  
  # Security configuration
  protocols {
    enable_http2 = true
  }
  
  security {
    enable_backend_ssl30                                = false
    enable_backend_tls10                                = false
    enable_backend_tls11                                = false
    enable_frontend_ssl30                               = false
    enable_frontend_tls10                               = false
    enable_frontend_tls11                               = false
    tls_ecdhe_ecdsa_with_aes128_cbc_sha_ciphers_enabled = false
    tls_ecdhe_ecdsa_with_aes256_cbc_sha_ciphers_enabled = false
    tls_ecdhe_rsa_with_aes128_cbc_sha_ciphers_enabled   = false
    tls_ecdhe_rsa_with_aes256_cbc_sha_ciphers_enabled   = false
    tls_rsa_with_aes128_cbc_sha256_ciphers_enabled      = false
    tls_rsa_with_aes128_cbc_sha_ciphers_enabled         = false
    tls_rsa_with_aes128_gcm_sha256_ciphers_enabled      = true
    tls_rsa_with_aes256_cbc_sha256_ciphers_enabled      = false
    tls_rsa_with_aes256_cbc_sha_ciphers_enabled         = false
    tls_rsa_with_aes256_gcm_sha384_ciphers_enabled      = true
  }
  
  # Sign-in and sign-up configuration
  sign_in {
    enabled = true
  }
  
  sign_up {
    enabled = true
    terms_of_service {
      enabled          = true
      consent_required = true
      text            = "Terms of service for API access"
    }
  }
  
  tags = local.common_tags
}

# ===============================================================================
# KEY VAULT ACCESS FOR APIM
# ===============================================================================

resource "azurerm_key_vault_access_policy" "apim" {
  key_vault_id = var.key_vault_id
  tenant_id    = azurerm_api_management.main.identity[0].tenant_id
  object_id    = azurerm_api_management.main.identity[0].principal_id
  
  certificate_permissions = [
    "Get", "List"
  ]
  
  secret_permissions = [
    "Get", "List"
  ]
}

# ===============================================================================
# API MANAGEMENT APIS
# ===============================================================================

resource "azurerm_api_management_api" "apis" {
  for_each = local.apis
  
  name                = each.value.name
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.main.name
  revision            = "1"
  display_name        = each.value.display_name
  path                = each.value.path
  protocols           = each.value.protocols
  description         = each.value.description
  
  service_url = each.value.backend_url
  
  subscription_required = true
  
  import {
    content_format = "openapi+json"
    content_value = jsonencode({
      openapi = "3.0.0"
      info = {
        title       = each.value.display_name
        description = each.value.description
        version     = "1.0.0"
      }
      servers = [{
        url = each.value.backend_url
      }]
      paths = {
        for op_key, operation in each.value.operations : operation.url_template => {
          (lower(operation.method)) = {
            summary     = operation.display_name
            description = operation.description
            responses = {
              "200" = {
                description = "Success"
              }
            }
          }
        }
      }
    })
  }
}

# ===============================================================================
# API OPERATIONS
# ===============================================================================

resource "azurerm_api_management_api_operation" "operations" {
  for_each = {
    for combo in flatten([
      for api_key, api in local.apis : [
        for op_key, operation in api.operations : {
          key          = "${api_key}_${op_key}"
          api_key      = api_key
          operation    = operation
          api_name     = api.name
        }
      ]
    ]) : combo.key => combo
  }
  
  operation_id        = each.value.operation.display_name
  api_name           = azurerm_api_management_api.apis[each.value.api_key].name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  display_name       = each.value.operation.display_name
  method             = each.value.operation.method
  url_template       = each.value.operation.url_template
  description        = each.value.operation.description
  
  response {
    status_code = 200
    description = "Success"
  }
}

# ===============================================================================
# API MANAGEMENT PRODUCTS
# ===============================================================================

resource "azurerm_api_management_product" "products" {
  for_each = local.products
  
  product_id          = each.value.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  display_name        = each.value.display_name
  description         = each.value.description
  published           = each.value.published
  approval_required   = each.value.approval_required
  subscription_required = each.value.subscription_required
  subscriptions_limit = each.value.subscriptions_limit
}

# ===============================================================================
# PRODUCT API ASSOCIATIONS
# ===============================================================================

resource "azurerm_api_management_product_api" "associations" {
  for_each = {
    for combo in flatten([
      for product_key, product in local.products : [
        for api_key, api in local.apis : {
          key         = "${product_key}_${api_key}"
          product_id  = product.name
          api_name    = api.name
        }
      ]
    ]) : combo.key => combo
  }
  
  api_name            = azurerm_api_management_api.apis[split("_", each.key)[1]].name
  product_id          = azurerm_api_management_product.products[split("_", each.key)[0]].product_id
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
}

# ===============================================================================
# API MANAGEMENT POLICIES
# ===============================================================================

# Global policy
resource "azurerm_api_management_api_policy" "global" {
  api_name            = azurerm_api_management_api.apis["ecommerce_api"].name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  
  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <cors allow-credentials="true">
      <allowed-origins>
        <origin>*</origin>
      </allowed-origins>
      <allowed-methods>
        <method>GET</method>
        <method>POST</method>
        <method>PUT</method>
        <method>DELETE</method>
        <method>OPTIONS</method>
      </allowed-methods>
      <allowed-headers>
        <header>*</header>
      </allowed-headers>
    </cors>
    <rate-limit-by-key calls="1000" renewal-period="3600" counter-key="@(context.Subscription?.Id ?? "anonymous")" />
    <quota-by-key calls="10000" renewal-period="86400" counter-key="@(context.Subscription?.Id ?? "anonymous")" />
    <set-header name="X-Forwarded-For" exists-action="override">
      <value>@(context.Request.IpAddress)</value>
    </set-header>
    <set-header name="X-API-Version" exists-action="override">
      <value>v1</value>
    </set-header>
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
    <set-header name="X-Powered-By" exists-action="delete" />
    <set-header name="Server" exists-action="delete" />
  </outbound>
  <on-error>
    <base />
    <set-header name="ErrorSource" exists-action="override">
      <value>@(context.LastError.Source)</value>
    </set-header>
    <set-header name="ErrorReason" exists-action="override">
      <value>@(context.LastError.Reason)</value>
    </set-header>
  </on-error>
</policies>
XML
}

# Payment API specific policy (higher security)
resource "azurerm_api_management_api_policy" "payment_api" {
  api_name            = azurerm_api_management_api.apis["payment_api"].name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  
  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <rate-limit-by-key calls="100" renewal-period="3600" counter-key="@(context.Subscription?.Id ?? "anonymous")" />
    <quota-by-key calls="1000" renewal-period="86400" counter-key="@(context.Subscription?.Id ?? "anonymous")" />
    <validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized">
      <openid-config url="https://login.microsoftonline.com/common/.well-known/openid_configuration" />
      <required-claims>
        <claim name="aud">
          <value>api://payment-service</value>
        </claim>
      </required-claims>
    </validate-jwt>
    <set-header name="X-Payment-Request-Id" exists-action="override">
      <value>@(Guid.NewGuid().ToString())</value>
    </set-header>
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
    <set-header name="X-Payment-Response-Time" exists-action="override">
      <value>@(context.Response.Headers.GetValueOrDefault("Date",""))</value>
    </set-header>
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML
}

# ===============================================================================
# PRODUCT POLICIES
# ===============================================================================

resource "azurerm_api_management_product_policy" "starter" {
  product_id          = azurerm_api_management_product.products["starter"].product_id
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  
  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <rate-limit calls="500" renewal-period="3600" />
    <quota calls="5000" renewal-period="86400" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML
}

resource "azurerm_api_management_product_policy" "premium" {
  product_id          = azurerm_api_management_product.products["premium"].product_id
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  
  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <rate-limit calls="2000" renewal-period="3600" />
    <quota calls="50000" renewal-period="86400" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML
}

# ===============================================================================
# DIAGNOSTIC SETTINGS
# ===============================================================================

resource "azurerm_api_management_diagnostic" "application_insights" {
  identifier               = "applicationinsights"
  resource_group_name      = var.resource_group_name
  api_management_name      = azurerm_api_management.main.name
  api_management_logger_id = azurerm_api_management_logger.application_insights.id
  
  sampling_percentage       = 100.0
  always_log_errors        = true
  log_client_ip            = true
  verbosity                = "information"
  http_correlation_protocol = "W3C"
  
  frontend_request {
    body_bytes = 1024
    headers_to_log = [
      "content-type",
      "accept",
      "origin"
    ]
  }
  
  frontend_response {
    body_bytes = 1024
    headers_to_log = [
      "content-type",
      "content-length",
      "server"
    ]
  }
  
  backend_request {
    body_bytes = 1024
    headers_to_log = [
      "content-type",
      "accept",
      "origin"
    ]
  }
  
  backend_response {
    body_bytes = 1024
    headers_to_log = [
      "content-type",
      "content-length",
      "server"
    ]
  }
}

# ===============================================================================
# APPLICATION INSIGHTS LOGGER
# ===============================================================================

resource "azurerm_application_insights" "apim" {
  name                = "${local.name_prefix}-apim-insights"
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"
  
  tags = local.common_tags
}

resource "azurerm_api_management_logger" "application_insights" {
  name                = "application-insights-logger"
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  
  application_insights {
    instrumentation_key = azurerm_application_insights.apim.instrumentation_key
  }
}
