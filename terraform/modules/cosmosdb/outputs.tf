# ===============================================================================
# COSMOSDB MODULE - OUTPUTS
# ===============================================================================

# CosmosDB Account
output "id" {
  description = "ID da conta CosmosDB"
  value       = azurerm_cosmosdb_account.main.id
}

output "name" {
  description = "Nome da conta CosmosDB"
  value       = azurerm_cosmosdb_account.main.name
}

output "endpoint" {
  description = "Endpoint da conta CosmosDB"
  value       = azurerm_cosmosdb_account.main.endpoint
}

output "read_endpoints" {
  description = "Endpoints de leitura da conta CosmosDB"
  value       = azurerm_cosmosdb_account.main.read_endpoints
}

output "write_endpoints" {
  description = "Endpoints de escrita da conta CosmosDB"
  value       = azurerm_cosmosdb_account.main.write_endpoints
}

# Connection Strings and Keys
output "primary_key" {
  description = "Chave primária da conta CosmosDB"
  value       = azurerm_cosmosdb_account.main.primary_key
  sensitive   = true
}

output "secondary_key" {
  description = "Chave secundária da conta CosmosDB"
  value       = azurerm_cosmosdb_account.main.secondary_key
  sensitive   = true
}

output "primary_readonly_key" {
  description = "Chave primária somente leitura da conta CosmosDB"
  value       = azurerm_cosmosdb_account.main.primary_readonly_key
  sensitive   = true
}

output "secondary_readonly_key" {
  description = "Chave secundária somente leitura da conta CosmosDB"
  value       = azurerm_cosmosdb_account.main.secondary_readonly_key
  sensitive   = true
}

output "connection_strings" {
  description = "Strings de conexão da conta CosmosDB"
  value       = azurerm_cosmosdb_account.main.connection_strings
  sensitive   = true
}

output "primary_sql_connection_string" {
  description = "String de conexão SQL primária"
  value       = "AccountEndpoint=${azurerm_cosmosdb_account.main.endpoint};AccountKey=${azurerm_cosmosdb_account.main.primary_key};"
  sensitive   = true
}

output "primary_readonly_connection_string" {
  description = "String de conexão somente leitura primária"
  value       = "AccountEndpoint=${azurerm_cosmosdb_account.main.endpoint};AccountKey=${azurerm_cosmosdb_account.main.primary_readonly_key};"
  sensitive   = true
}

output "secondary_readonly_connection_string" {
  description = "String de conexão somente leitura secundária"
  value       = "AccountEndpoint=${azurerm_cosmosdb_account.main.endpoint};AccountKey=${azurerm_cosmosdb_account.main.secondary_readonly_key};"
  sensitive   = true
}

# Databases
output "databases" {
  description = "Informações dos bancos de dados criados"
  value = {
    for db_name, db in azurerm_cosmosdb_sql_database.databases : db_name => {
      id   = db.id
      name = db.name
    }
  }
}

# Containers
output "containers" {
  description = "Informações dos containers criados"
  value = {
    for container_key, container in azurerm_cosmosdb_sql_container.containers : container_key => {
      id                 = container.id
      name               = container.name
      database_name      = container.database_name
      partition_key_path = container.partition_key_path
      throughput         = container.throughput
    }
  }
}

# Stored Procedures
output "stored_procedures" {
  description = "Informações dos stored procedures criados"
  value = {
    bulk_insert_orders = {
      id   = azurerm_cosmosdb_sql_stored_procedure.bulk_insert_orders.id
      name = azurerm_cosmosdb_sql_stored_procedure.bulk_insert_orders.name
    }
    validate_user = {
      id   = azurerm_cosmosdb_sql_stored_procedure.validate_user.id
      name = azurerm_cosmosdb_sql_stored_procedure.validate_user.name
    }
  }
}

# User Defined Functions
output "user_defined_functions" {
  description = "Informações das UDFs criadas"
  value = {
    calculate_order_total = {
      id   = azurerm_cosmosdb_sql_user_defined_function.calculate_order_total.id
      name = azurerm_cosmosdb_sql_user_defined_function.calculate_order_total.name
    }
    format_currency = {
      id   = azurerm_cosmosdb_sql_user_defined_function.format_currency.id
      name = azurerm_cosmosdb_sql_user_defined_function.format_currency.name
    }
  }
}

# Triggers
output "triggers" {
  description = "Informações dos triggers criados"
  value = {
    validate_order_pre = {
      id   = azurerm_cosmosdb_sql_trigger.validate_order_pre.id
      name = azurerm_cosmosdb_sql_trigger.validate_order_pre.name
      type = azurerm_cosmosdb_sql_trigger.validate_order_pre.type
    }
    order_analytics_post = {
      id   = azurerm_cosmosdb_sql_trigger.order_analytics_post.id
      name = azurerm_cosmosdb_sql_trigger.order_analytics_post.name
      type = azurerm_cosmosdb_sql_trigger.order_analytics_post.type
    }
  }
}

# Identity
output "identity" {
  description = "Informações da identidade gerenciada"
  value = {
    principal_id = azurerm_cosmosdb_account.main.identity[0].principal_id
    tenant_id    = azurerm_cosmosdb_account.main.identity[0].tenant_id
  }
}

# Configuration for Applications
output "application_config" {
  description = "Configuração para uso em aplicações"
  value = {
    endpoint = azurerm_cosmosdb_account.main.endpoint
    databases = {
      for db_name, db_config in var.databases : db_name => {
        name = db_name
        containers = {
          for container_name, container_config in db_config.containers : container_name => {
            name               = container_name
            partition_key_path = container_config.partition_key_path
          }
        }
      }
    }
  }
}

# SDK Configuration
output "sdk_config" {
  description = "Configuração para SDKs de diferentes linguagens"
  value = {
    dotnet = {
      endpoint = azurerm_cosmosdb_account.main.endpoint
      database_name = "ecommerce"
      container_names = {
        users    = "users"
        orders   = "orders"
        products = "products"
        payments = "payments"
      }
    }
    nodejs = {
      endpoint = azurerm_cosmosdb_account.main.endpoint
      database = "ecommerce"
      containers = {
        users    = "users"
        orders   = "orders"
        products = "products"
        payments = "payments"
      }
    }
    python = {
      endpoint = azurerm_cosmosdb_account.main.endpoint
      database_name = "ecommerce"
      container_names = [
        "users",
        "orders", 
        "products",
        "payments"
      ]
    }
  }
}

# Monitoring Information
output "monitoring_info" {
  description = "Informações para monitoramento"
  value = {
    account_name = azurerm_cosmosdb_account.main.name
    resource_id  = azurerm_cosmosdb_account.main.id
    metrics_endpoints = {
      primary   = "${azurerm_cosmosdb_account.main.endpoint}/_explorer/index.html"
      analytics = "${azurerm_cosmosdb_account.main.endpoint}/_explorer/index.html#/analytics"
    }
    diagnostic_setting_id = azurerm_monitor_diagnostic_setting.cosmosdb.id
  }
}

# Backup Information
output "backup_info" {
  description = "Informações de backup"
  value = {
    type                = var.backup_type
    interval_in_minutes = var.backup_interval_in_minutes
    retention_in_hours  = var.backup_retention_in_hours
    storage_redundancy  = "Geo"
  }
}

# Network Configuration
output "network_config" {
  description = "Configuração de rede"
  value = {
    virtual_network_filter_enabled = var.enable_virtual_network_filter
    public_network_access_enabled  = azurerm_cosmosdb_account.main.public_network_access_enabled
    ip_range_filter               = azurerm_cosmosdb_account.main.ip_range_filter
  }
}
