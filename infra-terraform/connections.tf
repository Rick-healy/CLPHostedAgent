locals {
  requested_connection_map = {
    for connection in local.requested_connections : connection.name => merge(
      {
        category      = connection.category
        target        = connection.target
        authType      = connection.authType
        isSharedToAll = try(connection.isSharedToAll, true)
      },
      try(connection.metadata, null) != null ? { metadata = connection.metadata } : {},
      try(local.connection_credentials[connection.name], null) != null ? {
        credentials = local.connection_credentials[connection.name]
      } : {},
      try(connection.error, null) != null ? { error = connection.error } : {},
      try(connection.expiryTime, null) != null ? { expiryTime = connection.expiryTime } : {},
      try(connection.peRequirement, null) != null ? { peRequirement = connection.peRequirement } : {},
      try(connection.peStatus, null) != null ? { peStatus = connection.peStatus } : {},
      try(connection.sharedUserList, null) != null ? { sharedUserList = connection.sharedUserList } : {},
      try(connection.useWorkspaceManagedIdentity, null) != null ? { useWorkspaceManagedIdentity = connection.useWorkspaceManagedIdentity } : {},
      try(connection.authorizationUrl, null) != null ? { authorizationUrl = connection.authorizationUrl } : {},
      try(connection.tokenUrl, null) != null ? { tokenUrl = connection.tokenUrl } : {},
      try(connection.refreshUrl, null) != null ? { refreshUrl = connection.refreshUrl } : {},
      try(connection.scopes, null) != null ? { scopes = connection.scopes } : {},
      try(connection.audience, null) != null ? { audience = connection.audience } : {},
      try(connection.connectorName, null) != null ? { connectorName = connection.connectorName } : {}
    )
  }

  app_insights_connection = local.should_create_monitoring || local.should_connect_existing_appi ? {
    "appi-${local.resource_token}" = {
      category      = "AppInsights"
      target        = local.should_create_monitoring ? azurerm_application_insights.main[0].id : var.existing_application_insights_resource_id
      authType      = "ApiKey"
      isSharedToAll = true
      credentials = {
        key = local.should_create_monitoring ? azurerm_application_insights.main[0].connection_string : var.existing_application_insights_connection_string
      }
      metadata = {
        ApiType    = "Azure"
        ResourceId = local.should_create_monitoring ? azurerm_application_insights.main[0].id : var.existing_application_insights_resource_id
      }
    }
  } : {}

  acr_connection = local.should_create_acr || (local.has_existing_acr && !local.has_existing_acr_link && !var.use_existing_ai_project) ? {
    (local.acr_connection_name) = {
      category      = "ContainerRegistry"
      target        = local.acr_login_server
      authType      = "ManagedIdentity"
      isSharedToAll = true
      credentials = {
        clientId   = local.project_principal_id
        resourceId = local.should_create_acr ? azurerm_container_registry.main[0].id : var.existing_container_registry_resource_id
      }
      metadata = {
        ResourceId = local.should_create_acr ? azurerm_container_registry.main[0].id : var.existing_container_registry_resource_id
      }
    }
  } : {}

  storage_connection = !var.use_existing_ai_project && local.has_storage ? {
    (local.dependent_resources_by_type.storage.connectionName) = {
      category      = "AzureStorageAccount"
      target        = azurerm_storage_account.main[0].primary_blob_endpoint
      authType      = "AAD"
      isSharedToAll = true
      metadata = {
        ApiType    = "Azure"
        ResourceId = azurerm_storage_account.main[0].id
        location   = azurerm_storage_account.main[0].location
      }
    }
  } : {}

  search_connection = !var.use_existing_ai_project && local.has_search ? {
    (local.dependent_resources_by_type.azure_ai_search.connectionName) = {
      category      = "CognitiveSearch"
      target        = "https://${azurerm_search_service.main[0].name}.search.windows.net"
      authType      = "AAD"
      isSharedToAll = true
      metadata = {
        ApiType    = "Azure"
        ApiVersion = "2024-07-01"
        ResourceId = azurerm_search_service.main[0].id
        type       = "azure_ai_search"
      }
    }
  } : {}

  bing_connection = !var.use_existing_ai_project && local.has_bing ? {
    (local.dependent_resources_by_type.bing_grounding.connectionName) = {
      category      = "GroundingWithBingSearch"
      target        = try(azapi_resource.bing[0].output.properties.endpoint, "")
      authType      = "ApiKey"
      isSharedToAll = true
      credentials = {
        key = try(azapi_resource_action.bing_keys[0].output.key1, "")
      }
      metadata = {
        ApiType    = "Azure"
        Location   = "global"
        ResourceId = azapi_resource.bing[0].id
        type       = "bing_grounding"
      }
    }
  } : {}

  bing_custom_connection = !var.use_existing_ai_project && local.has_bing_custom ? {
    (local.dependent_resources_by_type.bing_custom_grounding.connectionName) = {
      category      = "GroundingWithCustomSearch"
      target        = try(azapi_resource.bing_custom[0].output.properties.endpoint, "")
      authType      = "ApiKey"
      isSharedToAll = true
      credentials = {
        key = try(azapi_resource_action.bing_custom_keys[0].output.key1, "")
      }
      metadata = {
        ApiType    = "Azure"
        Location   = "global"
        ResourceId = azapi_resource.bing_custom[0].id
        type       = "bing_custom_search"
      }
    }
  } : {}

  project_connections = merge(
    local.requested_connection_map,
    local.app_insights_connection,
    local.acr_connection,
    local.storage_connection,
    local.search_connection,
    local.bing_connection,
    local.bing_custom_connection
  )
}

resource "azapi_resource" "project_connection" {
  for_each = local.project_connections

  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview"
  name      = each.key
  parent_id = local.project_id

  body = {
    properties = each.value
  }

  response_export_values = ["*"]
}