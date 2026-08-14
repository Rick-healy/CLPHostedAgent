output "AZURE_RESOURCE_GROUP" {
  value = azurerm_resource_group.main.name
}

output "AZURE_AI_ACCOUNT_ID" {
  value = local.account_id
}

output "AZURE_AI_PROJECT_ID" {
  value = local.project_id
}

output "AZURE_AI_FOUNDRY_PROJECT_ID" {
  value = local.project_id
}

output "AZURE_AI_ACCOUNT_NAME" {
  value = local.account_name
}

output "AZURE_AI_PROJECT_NAME" {
  value = var.ai_foundry_project_name
}

output "AZURE_AI_PROJECT_ENDPOINT" {
  value = local.foundry_project_endpoint
}

output "FOUNDRY_PROJECT_ENDPOINT" {
  value = local.foundry_project_endpoint
}

output "AZURE_OPENAI_ENDPOINT" {
  value = local.azure_openai_endpoint
}

output "APPLICATIONINSIGHTS_CONNECTION_STRING" {
  value     = local.should_create_monitoring ? azurerm_application_insights.main[0].connection_string : var.existing_application_insights_connection_string
  sensitive = true
}

output "APPLICATIONINSIGHTS_RESOURCE_ID" {
  value = local.should_create_monitoring ? azurerm_application_insights.main[0].id : var.existing_application_insights_resource_id
}

output "AZURE_AI_PROJECT_ACR_CONNECTION_NAME" {
  value = local.acr_connection_name
}

output "AZURE_CONTAINER_REGISTRY_ENDPOINT" {
  value = local.acr_login_server
}

output "BING_GROUNDING_CONNECTION_NAME" {
  value = !var.use_existing_ai_project && local.has_bing ? local.dependent_resources_by_type.bing_grounding.connectionName : ""
}

output "BING_GROUNDING_RESOURCE_NAME" {
  value = !var.use_existing_ai_project && local.has_bing ? azapi_resource.bing[0].name : ""
}

output "BING_GROUNDING_CONNECTION_ID" {
  value = !var.use_existing_ai_project && local.has_bing ? azapi_resource.project_connection[local.dependent_resources_by_type.bing_grounding.connectionName].id : ""
}

output "BING_CUSTOM_GROUNDING_CONNECTION_NAME" {
  value = !var.use_existing_ai_project && local.has_bing_custom ? local.dependent_resources_by_type.bing_custom_grounding.connectionName : ""
}

output "BING_CUSTOM_GROUNDING_NAME" {
  value = !var.use_existing_ai_project && local.has_bing_custom ? azapi_resource.bing_custom[0].name : ""
}

output "BING_CUSTOM_GROUNDING_CONNECTION_ID" {
  value = !var.use_existing_ai_project && local.has_bing_custom ? azapi_resource.project_connection[local.dependent_resources_by_type.bing_custom_grounding.connectionName].id : ""
}

output "AZURE_AI_SEARCH_CONNECTION_NAME" {
  value = !var.use_existing_ai_project && local.has_search ? local.dependent_resources_by_type.azure_ai_search.connectionName : ""
}

output "AZURE_AI_SEARCH_SERVICE_NAME" {
  value = !var.use_existing_ai_project && local.has_search ? azurerm_search_service.main[0].name : ""
}

output "AZURE_STORAGE_CONNECTION_NAME" {
  value = !var.use_existing_ai_project && local.has_storage ? local.dependent_resources_by_type.storage.connectionName : ""
}

output "AZURE_STORAGE_ACCOUNT_NAME" {
  value = !var.use_existing_ai_project && local.has_storage ? azurerm_storage_account.main[0].name : ""
}

output "AI_PROJECT_CONNECTION_IDS_JSON" {
  value = jsonencode([
    for name, connection in azapi_resource.project_connection : {
      name = name
      id   = connection.id
    }
  ])
}