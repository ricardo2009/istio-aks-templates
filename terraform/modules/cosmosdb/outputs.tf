# ===============================================================================
# COSMOSDB MODULE - SIMPLIFIED OUTPUTS
# ===============================================================================

output "cosmosdb_account_id" {
  description = "ID da conta CosmosDB"
  value       = azurerm_cosmosdb_account.main.id
}

output "cosmosdb_account_name" {
  description = "Nome da conta CosmosDB"
  value       = azurerm_cosmosdb_account.main.name
}

output "endpoint" {
  description = "Endpoint da conta CosmosDB"
  value       = azurerm_cosmosdb_account.main.endpoint
}

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

output "connection_strings" {
  description = "Strings de conexão da conta CosmosDB"
  value       = azurerm_cosmosdb_account.main.connection_strings
  sensitive   = true
}

output "databases" {
  description = "Informações dos bancos de dados"
  value = {
    ecommerce = {
      id   = azurerm_cosmosdb_sql_database.ecommerce.id
      name = azurerm_cosmosdb_sql_database.ecommerce.name
    }
    analytics = {
      id   = azurerm_cosmosdb_sql_database.analytics.id
      name = azurerm_cosmosdb_sql_database.analytics.name
    }
  }
}

output "containers" {
  description = "Informações dos containers"
  value = {
    users = {
      id   = azurerm_cosmosdb_sql_container.users.id
      name = azurerm_cosmosdb_sql_container.users.name
    }
    products = {
      id   = azurerm_cosmosdb_sql_container.products.id
      name = azurerm_cosmosdb_sql_container.products.name
    }
    orders = {
      id   = azurerm_cosmosdb_sql_container.orders.id
      name = azurerm_cosmosdb_sql_container.orders.name
    }
    payments = {
      id   = azurerm_cosmosdb_sql_container.payments.id
      name = azurerm_cosmosdb_sql_container.payments.name
    }
    events = {
      id   = azurerm_cosmosdb_sql_container.events.id
      name = azurerm_cosmosdb_sql_container.events.name
    }
    metrics = {
      id   = azurerm_cosmosdb_sql_container.metrics.id
      name = azurerm_cosmosdb_sql_container.metrics.name
    }
  }
}

output "read_endpoints" {
  description = "Endpoints de leitura por região"
  value       = azurerm_cosmosdb_account.main.read_endpoints
}

output "write_endpoints" {
  description = "Endpoints de escrita por região"
  value       = azurerm_cosmosdb_account.main.write_endpoints
}
