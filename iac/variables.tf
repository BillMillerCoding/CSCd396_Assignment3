variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of the Azure Resource Group."
  type        = string
  default     = "rg-cscd396-assignment3"
}

variable "project_prefix" {
  description = "Short prefix used to generate unique resource names."
  type        = string
  default     = "cscd396a3"
}

variable "container_image" {
  description = "Full Docker image reference for the web app container (e.g. myregistry.azurecr.io/webapp:latest)."
  type        = string
}

variable "container_registry_server" {
  description = "Azure Container Registry server (e.g. myregistry.azurecr.io)."
  type        = string
}
