locals {
  # Unique suffix based on the resource group name to keep resource names short and unique
  suffix = lower(substr(md5(var.resource_group_name), 0, 6))
}

# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# ---------------------------------------------------------------------------
# Service Bus
# ---------------------------------------------------------------------------
resource "azurerm_servicebus_namespace" "main" {
  name                = "${var.project_prefix}-sb-${local.suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_servicebus_queue" "main" {
  name         = "messages"
  namespace_id = azurerm_servicebus_namespace.main.id
}

# ---------------------------------------------------------------------------
# Storage Account (for Function App message storage)
# ---------------------------------------------------------------------------
resource "azurerm_storage_account" "messages" {
  name                     = "${var.project_prefix}msg${local.suffix}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "messages" {
  name                  = "messages"
  storage_account_name  = azurerm_storage_account.messages.name
  container_access_type = "private"
}

# ---------------------------------------------------------------------------
# Storage Account (for Azure Function App hosting / AzureWebJobsStorage)
# ---------------------------------------------------------------------------
resource "azurerm_storage_account" "function" {
  name                     = "${var.project_prefix}fn${local.suffix}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# ---------------------------------------------------------------------------
# App Service Plan (for Function App)
# ---------------------------------------------------------------------------
resource "azurerm_service_plan" "function" {
  name                = "${var.project_prefix}-asp-${local.suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = "Y1" # Consumption plan
}

# ---------------------------------------------------------------------------
# Function App
# ---------------------------------------------------------------------------
resource "azurerm_linux_function_app" "main" {
  name                       = "${var.project_prefix}-func-${local.suffix}"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  service_plan_id            = azurerm_service_plan.function.id
  storage_account_name       = azurerm_storage_account.function.name
  storage_account_access_key = azurerm_storage_account.function.primary_access_key

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      dotnet_version              = "8.0"
      use_dotnet_isolated_runtime = true
    }
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"    = "dotnet-isolated"
    "SERVICEBUS_QUEUE_NAME"       = azurerm_servicebus_queue.main.name
    "ServiceBusConnection__fullyQualifiedNamespace" = "${azurerm_servicebus_namespace.main.name}.servicebus.windows.net"
    "STORAGE_ACCOUNT_NAME"        = azurerm_storage_account.messages.name
    "STORAGE_CONTAINER_NAME"      = azurerm_storage_container.messages.name
    "WEBSITE_RUN_FROM_PACKAGE"    = "1"
  }
}

# Grant Function App Managed Identity access to the messages Storage Account (Storage Blob Data Contributor)
resource "azurerm_role_assignment" "function_storage_blob" {
  scope                = azurerm_storage_account.messages.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id
}

# Grant Function App Managed Identity access to Service Bus (Azure Service Bus Data Receiver)
resource "azurerm_role_assignment" "function_servicebus_receiver" {
  scope                = azurerm_servicebus_namespace.main.id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id
}

# ---------------------------------------------------------------------------
# Container Registry
# ---------------------------------------------------------------------------
resource "azurerm_container_registry" "main" {
  name                = "${var.project_prefix}acr${local.suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = false
}

# ---------------------------------------------------------------------------
# Container App Environment
# ---------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.project_prefix}-law-${local.suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "main" {
  name                       = "${var.project_prefix}-cae-${local.suffix}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
}

# ---------------------------------------------------------------------------
# Container App (Web App)
# ---------------------------------------------------------------------------
resource "azurerm_container_app" "webapp" {
  name                         = "${var.project_prefix}-ca-${local.suffix}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  identity {
    type = "SystemAssigned"
  }

  registry {
    server   = var.container_registry_server
    identity = "system"
  }

  template {
    container {
      name   = "webapp"
      image  = var.container_image
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "SERVICEBUS_NAMESPACE"
        value = "${azurerm_servicebus_namespace.main.name}.servicebus.windows.net"
      }

      env {
        name  = "SERVICEBUS_QUEUE_NAME"
        value = azurerm_servicebus_queue.main.name
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8080

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

# Grant Container App Managed Identity access to the ACR (AcrPull)
resource "azurerm_role_assignment" "webapp_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.webapp.identity[0].principal_id
}

# Grant Container App Managed Identity permission to send messages to Service Bus (Azure Service Bus Data Sender)
resource "azurerm_role_assignment" "webapp_servicebus_sender" {
  scope                = azurerm_servicebus_namespace.main.id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = azurerm_container_app.webapp.identity[0].principal_id
}
