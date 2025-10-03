# ===============================================================================
# COSMOSDB MODULE - MAIN CONFIGURATION
# ===============================================================================
# Módulo responsável por configurar Azure CosmosDB
# Inclui: Account, Databases, Containers, Backup, Network Rules
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
  account_name = "${replace(local.name_prefix, "-", "")}cosmos"
  
  # Consistency level configuration
  consistency_policy = {
    consistency_level       = var.consistency_level
    max_interval_in_seconds = var.max_interval_in_seconds
    max_staleness_prefix    = var.max_staleness_prefix
  }
  
  # Common tags
  common_tags = merge(var.tags, {
    Module = "cosmosdb"
  })
}

# ===============================================================================
# RANDOM RESOURCES
# ===============================================================================

resource "random_id" "cosmos_suffix" {
  byte_length = 4
}

# ===============================================================================
# COSMOSDB ACCOUNT
# ===============================================================================

resource "azurerm_cosmosdb_account" "main" {
  name                = "${local.account_name}${random_id.cosmos_suffix.hex}"
  location            = var.location
  resource_group_name = var.resource_group_name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  
  # Multi-region configuration
  enable_multiple_write_locations = true
  enable_automatic_failover       = true
  
  # Consistency policy
  consistency_policy {
    consistency_level       = local.consistency_policy.consistency_level
    max_interval_in_seconds = local.consistency_policy.max_interval_in_seconds
    max_staleness_prefix    = local.consistency_policy.max_staleness_prefix
  }
  
  # Geo locations
  dynamic "geo_location" {
    for_each = var.failover_locations
    content {
      location          = geo_location.value.location
      failover_priority = geo_location.value.failover_priority
      zone_redundant    = geo_location.value.zone_redundant
    }
  }
  
  # Capabilities
  capabilities {
    name = "EnableServerless"
  }
  
  capabilities {
    name = "EnableTable"
  }
  
  capabilities {
    name = "EnableGremlin"
  }
  
  # Backup policy
  backup {
    type                = var.backup_type
    interval_in_minutes = var.backup_interval_in_minutes
    retention_in_hours  = var.backup_retention_in_hours
    storage_redundancy  = "Geo"
  }
  
  # Network configuration
  is_virtual_network_filter_enabled = var.enable_virtual_network_filter
  
  dynamic "virtual_network_rule" {
    for_each = var.virtual_network_rules
    content {
      id                                   = virtual_network_rule.value.id
      ignore_missing_vnet_service_endpoint = virtual_network_rule.value.ignore_missing_vnet_service_endpoint
    }
  }
  
  # IP firewall rules
  ip_range_filter = "0.0.0.0/0" # Allow all IPs initially, restrict in production
  
  # Security features
  enable_free_tier                 = false
  analytical_storage_enabled       = true
  enable_analytical_storage        = true
  public_network_access_enabled    = true
  network_acl_bypass_for_azure_services = true
  
  # Identity
  identity {
    type = "SystemAssigned"
  }
  
  tags = local.common_tags
}

# ===============================================================================
# COSMOSDB SQL DATABASES
# ===============================================================================

resource "azurerm_cosmosdb_sql_database" "databases" {
  for_each = var.databases
  
  name                = each.key
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
  
  # Throughput configuration
  dynamic "autoscale_settings" {
    for_each = each.value.throughput > 0 ? [] : [1]
    content {
      max_throughput = 4000
    }
  }
  
  throughput = each.value.throughput > 0 ? each.value.throughput : null
}

# ===============================================================================
# COSMOSDB SQL CONTAINERS
# ===============================================================================

resource "azurerm_cosmosdb_sql_container" "containers" {
  for_each = {
    for combo in flatten([
      for db_name, db_config in var.databases : [
        for container_name, container_config in db_config.containers : {
          key                = "${db_name}_${container_name}"
          database_name      = db_name
          container_name     = container_name
          partition_key_path = container_config.partition_key_path
          throughput         = container_config.throughput
        }
      ]
    ]) : combo.key => combo
  }
  
  name                = each.value.container_name
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_sql_database.databases[each.value.database_name].name
  partition_key_path  = each.value.partition_key_path
  
  # Throughput configuration
  dynamic "autoscale_settings" {
    for_each = each.value.throughput > 0 ? [] : [1]
    content {
      max_throughput = 1000
    }
  }
  
  throughput = each.value.throughput > 0 ? each.value.throughput : null
  
  # Indexing policy
  indexing_policy {
    indexing_mode = "consistent"
    
    included_path {
      path = "/*"
    }
    
    excluded_path {
      path = "/\"_etag\"/?"
    }
    
    # Composite indexes for common queries
    dynamic "composite_index" {
      for_each = each.value.container_name == "orders" ? [1] : []
      content {
        index {
          path  = "/customerId"
          order = "ascending"
        }
        index {
          path  = "/createdAt"
          order = "descending"
        }
      }
    }
    
    dynamic "composite_index" {
      for_each = each.value.container_name == "products" ? [1] : []
      content {
        index {
          path  = "/categoryId"
          order = "ascending"
        }
        index {
          path  = "/price"
          order = "ascending"
        }
      }
    }
  }
  
  # Unique key policy
  dynamic "unique_key" {
    for_each = each.value.container_name == "users" ? [1] : []
    content {
      paths = ["/email"]
    }
  }
  
  # Conflict resolution policy
  conflict_resolution_policy {
    mode                     = "LastWriterWins"
    conflict_resolution_path = "/_ts"
  }
}

# ===============================================================================
# STORED PROCEDURES
# ===============================================================================

# Bulk insert stored procedure for orders
resource "azurerm_cosmosdb_sql_stored_procedure" "bulk_insert_orders" {
  name                = "bulkInsertOrders"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_sql_database.databases["ecommerce"].name
  container_name      = azurerm_cosmosdb_sql_container.containers["ecommerce_orders"].name
  
  body = <<BODY
function bulkInsertOrders(orders) {
    var context = getContext();
    var container = context.getCollection();
    var response = context.getResponse();
    
    if (!orders) throw new Error("Orders array is required");
    
    var count = 0;
    var docs = [];
    
    function insertOrder(order) {
        if (count >= orders.length) {
            response.setBody({ created: docs.length, errors: [] });
            return;
        }
        
        var order = orders[count];
        order.id = order.id || generateId();
        order.createdAt = order.createdAt || new Date().toISOString();
        order.updatedAt = new Date().toISOString();
        
        var accepted = container.createDocument(
            container.getSelfLink(),
            order,
            function(err, doc) {
                if (err) {
                    throw new Error('Error creating document: ' + err.message);
                }
                docs.push(doc);
                count++;
                insertOrder();
            }
        );
        
        if (!accepted) {
            response.setBody({ created: docs.length, message: "Request quota exceeded" });
        }
    }
    
    function generateId() {
        return 'order_' + Math.random().toString(36).substr(2, 9) + '_' + Date.now();
    }
    
    insertOrder();
}
BODY
}

# User validation stored procedure
resource "azurerm_cosmosdb_sql_stored_procedure" "validate_user" {
  name                = "validateUser"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_sql_database.databases["ecommerce"].name
  container_name      = azurerm_cosmosdb_sql_container.containers["ecommerce_users"].name
  
  body = <<BODY
function validateUser(userId, email) {
    var context = getContext();
    var container = context.getCollection();
    var response = context.getResponse();
    
    if (!userId && !email) {
        throw new Error("Either userId or email is required");
    }
    
    var query = userId ? 
        "SELECT * FROM c WHERE c.id = '" + userId + "'" :
        "SELECT * FROM c WHERE c.email = '" + email + "'";
    
    var accepted = container.queryDocuments(
        container.getSelfLink(),
        query,
        function(err, documents) {
            if (err) {
                throw new Error('Error querying documents: ' + err.message);
            }
            
            if (documents.length === 0) {
                response.setBody({ valid: false, user: null });
            } else {
                var user = documents[0];
                response.setBody({ 
                    valid: true, 
                    user: {
                        id: user.id,
                        email: user.email,
                        name: user.name,
                        status: user.status,
                        lastLogin: user.lastLogin
                    }
                });
            }
        }
    );
    
    if (!accepted) {
        throw new Error("Query was not accepted by the server");
    }
}
BODY
}

# ===============================================================================
# USER DEFINED FUNCTIONS
# ===============================================================================

# Calculate order total UDF
resource "azurerm_cosmosdb_sql_user_defined_function" "calculate_order_total" {
  name                = "calculateOrderTotal"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_sql_database.databases["ecommerce"].name
  container_name      = azurerm_cosmosdb_sql_container.containers["ecommerce_orders"].name
  
  body = <<BODY
function calculateOrderTotal(items, taxRate, shippingCost) {
    if (!items || !Array.isArray(items)) {
        return 0;
    }
    
    var subtotal = items.reduce(function(sum, item) {
        return sum + (item.price * item.quantity);
    }, 0);
    
    var tax = subtotal * (taxRate || 0);
    var shipping = shippingCost || 0;
    
    return Math.round((subtotal + tax + shipping) * 100) / 100;
}
BODY
}

# Format currency UDF
resource "azurerm_cosmosdb_sql_user_defined_function" "format_currency" {
  name                = "formatCurrency"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_sql_database.databases["ecommerce"].name
  container_name      = azurerm_cosmosdb_sql_container.containers["ecommerce_products"].name
  
  body = <<BODY
function formatCurrency(amount, currency) {
    if (typeof amount !== 'number') {
        return '0.00';
    }
    
    var formatted = amount.toFixed(2);
    var currencySymbol = currency === 'EUR' ? '€' : 
                        currency === 'GBP' ? '£' : '$';
    
    return currencySymbol + formatted;
}
BODY
}

# ===============================================================================
# TRIGGERS
# ===============================================================================

# Pre-trigger for order validation
resource "azurerm_cosmosdb_sql_trigger" "validate_order_pre" {
  name                = "validateOrderPre"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_sql_database.databases["ecommerce"].name
  container_name      = azurerm_cosmosdb_sql_container.containers["ecommerce_orders"].name
  type                = "Pre"
  operation           = "Create"
  
  body = <<BODY
function validateOrderPre() {
    var context = getContext();
    var request = context.getRequest();
    var body = request.getBody();
    
    // Validate required fields
    if (!body.customerId) {
        throw new Error("customerId is required");
    }
    
    if (!body.items || !Array.isArray(body.items) || body.items.length === 0) {
        throw new Error("items array is required and cannot be empty");
    }
    
    // Validate each item
    body.items.forEach(function(item, index) {
        if (!item.productId) {
            throw new Error("productId is required for item " + index);
        }
        if (!item.quantity || item.quantity <= 0) {
            throw new Error("quantity must be greater than 0 for item " + index);
        }
        if (!item.price || item.price <= 0) {
            throw new Error("price must be greater than 0 for item " + index);
        }
    });
    
    // Set timestamps
    body.createdAt = new Date().toISOString();
    body.updatedAt = new Date().toISOString();
    body.status = body.status || "pending";
    
    // Generate order number if not provided
    if (!body.orderNumber) {
        body.orderNumber = "ORD-" + Date.now() + "-" + Math.random().toString(36).substr(2, 5).toUpperCase();
    }
    
    request.setBody(body);
}
BODY
}

# Post-trigger for order analytics
resource "azurerm_cosmosdb_sql_trigger" "order_analytics_post" {
  name                = "orderAnalyticsPost"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_sql_database.databases["ecommerce"].name
  container_name      = azurerm_cosmosdb_sql_container.containers["ecommerce_orders"].name
  type                = "Post"
  operation           = "Create"
  
  body = <<BODY
function orderAnalyticsPost() {
    var context = getContext();
    var container = context.getCollection();
    var response = context.getResponse();
    var createdDocument = response.getBody();
    
    // Create analytics event
    var analyticsEvent = {
        id: "analytics_" + createdDocument.id,
        eventType: "order_created",
        orderId: createdDocument.id,
        customerId: createdDocument.customerId,
        orderTotal: createdDocument.total,
        itemCount: createdDocument.items ? createdDocument.items.length : 0,
        timestamp: new Date().toISOString(),
        metadata: {
            source: "cosmosdb_trigger",
            version: "1.0"
        }
    };
    
    // Insert into analytics container (if exists)
    var analyticsAccepted = container.createDocument(
        container.getSelfLink().replace('/orders', '/events'),
        analyticsEvent,
        function(err, doc) {
            if (err) {
                console.log('Analytics event creation failed: ' + err.message);
            }
        }
    );
}
BODY
}

# ===============================================================================
# DIAGNOSTIC SETTINGS
# ===============================================================================

resource "azurerm_monitor_diagnostic_setting" "cosmosdb" {
  name               = "${azurerm_cosmosdb_account.main.name}-diagnostics"
  target_resource_id = azurerm_cosmosdb_account.main.id
  
  # Log Analytics Workspace (if provided)
  log_analytics_workspace_id = var.log_analytics_workspace_id
  
  # Metrics
  enabled_log {
    category = "DataPlaneRequests"
  }
  
  enabled_log {
    category = "QueryRuntimeStatistics"
  }
  
  enabled_log {
    category = "PartitionKeyStatistics"
  }
  
  enabled_log {
    category = "PartitionKeyRUConsumption"
  }
  
  enabled_log {
    category = "ControlPlaneRequests"
  }
  
  metric {
    category = "Requests"
    enabled  = true
  }
}
