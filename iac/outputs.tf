output "resource_group_name" {
  description = "Name of the Azure Resource Group."
  value       = azurerm_resource_group.main.name
}

output "service_bus_namespace" {
  description = "Fully-qualified Service Bus namespace hostname."
  value       = "${azurerm_servicebus_namespace.main.name}.servicebus.windows.net"
}

output "service_bus_queue_name" {
  description = "Name of the Service Bus queue."
  value       = azurerm_servicebus_queue.main.name
}

output "function_app_name" {
  description = "Name of the Azure Function App."
  value       = azurerm_linux_function_app.main.name
}

output "messages_storage_account_name" {
  description = "Name of the Storage Account used for messages."
  value       = azurerm_storage_account.messages.name
}

output "container_registry_login_server" {
  description = "Login server URL of the Azure Container Registry."
  value       = azurerm_container_registry.main.login_server
}

output "container_app_url" {
  description = "Public URL of the Container App."
  value       = "https://${azurerm_container_app.webapp.ingress[0].fqdn}"
}
