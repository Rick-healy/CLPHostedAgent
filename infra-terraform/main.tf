resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

data "azapi_resource" "existing_ai_account" {
  count = var.use_existing_ai_project ? 1 : 0

  type                   = "Microsoft.CognitiveServices/accounts@2025-06-01"
  resource_id            = "${azurerm_resource_group.main.id}/providers/Microsoft.CognitiveServices/accounts/${var.ai_foundry_resource_name}"
  response_export_values = ["*"]
}

data "azapi_resource" "existing_ai_project" {
  count = var.use_existing_ai_project ? 1 : 0

  type                   = "Microsoft.CognitiveServices/accounts/projects@2025-06-01"
  resource_id            = "${azurerm_resource_group.main.id}/providers/Microsoft.CognitiveServices/accounts/${var.ai_foundry_resource_name}/projects/${var.ai_foundry_project_name}"
  response_export_values = ["*"]
}

resource "azapi_resource" "ai_account" {
  count = var.use_existing_ai_project ? 0 : 1

  type      = "Microsoft.CognitiveServices/accounts@2025-06-01"
  name      = local.account_name
  parent_id = azurerm_resource_group.main.id
  location  = var.ai_deployments_location
  tags      = local.tags

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind = "AIServices"
    sku = {
      name = "S0"
    }
    properties = {
      allowProjectManagement = true
      customSubDomainName    = local.account_name
      disableLocalAuth       = true
      publicNetworkAccess    = "Enabled"
      networkAcls = {
        defaultAction       = "Allow"
        ipRules             = []
        virtualNetworkRules = []
      }
    }
  }

  response_export_values = ["*"]
}

resource "azapi_resource" "model_deployment" {
  for_each = { for deployment in local.deployments : deployment.name => deployment }

  type      = "Microsoft.CognitiveServices/accounts/deployments@2025-06-01"
  name      = each.key
  parent_id = local.account_id

  body = {
    properties = {
      model = each.value.model
    }
    sku = each.value.sku
  }
}

resource "azapi_resource" "ai_project" {
  count = var.use_existing_ai_project ? 0 : 1

  type      = "Microsoft.CognitiveServices/accounts/projects@2025-06-01"
  name      = var.ai_foundry_project_name
  parent_id = local.account_id
  location  = var.ai_deployments_location

  identity {
    type = "SystemAssigned"
  }

  body = {
    properties = {
      description = "${var.ai_foundry_project_name} Project"
      displayName = "${var.ai_foundry_project_name}Project"
    }
  }

  response_export_values = ["*"]
  depends_on             = [azapi_resource.model_deployment]
}

resource "azapi_resource" "capability_host" {
  count = !var.use_existing_ai_project && var.enable_hosted_agents && var.enable_capability_host ? 1 : 0

  type      = "Microsoft.CognitiveServices/accounts/capabilityHosts@2025-10-01-preview"
  name      = "agents"
  parent_id = local.account_id

  body = {
    properties = {
      capabilityHostKind             = "Agents"
      enablePublicHostingEnvironment = true
    }
  }
}

resource "azurerm_role_assignment" "deployer_ai_user" {
  count = var.use_existing_ai_project ? 0 : 1

  scope              = local.project_id
  role_definition_id = "/subscriptions/${var.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/53ca6127-db72-4b80-b1b0-d745d6d5456d"
  principal_id       = var.principal_id
  principal_type     = var.principal_type
}

resource "azurerm_container_registry" "main" {
  count = local.should_create_acr ? 1 : 0

  name                = "cr${local.resource_token}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = local.tags
}

resource "azurerm_role_assignment" "deployer_acr_tasks" {
  count = local.should_create_acr ? 1 : 0

  scope                = azurerm_container_registry.main[0].id
  role_definition_name = "Container Registry Tasks Contributor"
  principal_id         = var.principal_id
  principal_type       = var.principal_type
}

resource "azurerm_role_assignment" "project_acr_pull" {
  count = local.should_create_acr ? 1 : 0

  scope                = azurerm_container_registry.main[0].id
  role_definition_name = "AcrPull"
  principal_id         = local.project_principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "project_existing_acr_pull" {
  count = local.has_existing_acr && !local.has_existing_acr_link && !var.use_existing_ai_project ? 1 : 0

  scope                = var.existing_container_registry_resource_id
  role_definition_name = "AcrPull"
  principal_id         = local.project_principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_log_analytics_workspace" "main" {
  count = local.should_create_monitoring ? 1 : 0

  name                = "logs-${local.resource_token}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

resource "azurerm_application_insights" "main" {
  count = local.should_create_monitoring ? 1 : 0

  name                = "appi-${local.resource_token}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  workspace_id        = azurerm_log_analytics_workspace.main[0].id
  application_type    = "web"
  tags                = local.tags
}

resource "azurerm_role_assignment" "project_log_analytics_reader" {
  count = local.should_create_monitoring ? 1 : 0

  scope                = azurerm_application_insights.main[0].id
  role_definition_name = "Log Analytics Reader"
  principal_id         = local.project_principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_storage_account" "main" {
  count = !var.use_existing_ai_project && local.has_storage ? 1 : 0

  name                            = "st${local.resource_token}"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  access_tier                     = "Hot"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  tags                            = local.tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "project_storage_blob_contributor" {
  count = !var.use_existing_ai_project && local.has_storage ? 1 : 0

  scope                = azurerm_storage_account.main[0].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = local.project_principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "deployer_storage_blob_contributor" {
  count = !var.use_existing_ai_project && local.has_storage ? 1 : 0

  scope                = azurerm_storage_account.main[0].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.principal_id
  principal_type       = var.principal_type
}

resource "azurerm_search_service" "main" {
  count = !var.use_existing_ai_project && local.has_search ? 1 : 0

  name                          = "search-${local.resource_token}"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  sku                           = "basic"
  replica_count                 = 1
  partition_count               = 1
  public_network_access_enabled = true
  local_authentication_enabled  = true
  authentication_failure_mode   = "http401WithBearerChallenge"
  tags                          = local.tags

  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    precondition {
      condition     = local.has_storage
      error_message = "azure_ai_search requires storage in AI_PROJECT_DEPENDENT_RESOURCES."
    }
  }
}

resource "azurerm_storage_container" "knowledge" {
  count = !var.use_existing_ai_project && local.has_search && local.has_storage ? 1 : 0

  name                  = "knowledge"
  storage_account_id    = azurerm_storage_account.main[0].id
  container_access_type = "private"
}

resource "azurerm_role_assignment" "search_storage_reader" {
  count = !var.use_existing_ai_project && local.has_search && local.has_storage ? 1 : 0

  scope                = azurerm_storage_account.main[0].id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_search_service.main[0].identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "search_openai_user" {
  count = !var.use_existing_ai_project && local.has_search ? 1 : 0

  scope                = local.account_id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_search_service.main[0].identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "project_search_contributor" {
  count = !var.use_existing_ai_project && local.has_search ? 1 : 0

  scope                = azurerm_search_service.main[0].id
  role_definition_name = "Search Service Contributor"
  principal_id         = local.project_principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "project_search_data_contributor" {
  count = !var.use_existing_ai_project && local.has_search ? 1 : 0

  scope                = azurerm_search_service.main[0].id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = local.project_principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "deployer_search_data_contributor" {
  count = !var.use_existing_ai_project && local.has_search ? 1 : 0

  scope                = azurerm_search_service.main[0].id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = var.principal_id
  principal_type       = var.principal_type
}

resource "azapi_resource" "bing" {
  count = !var.use_existing_ai_project && local.has_bing ? 1 : 0

  type                      = "Microsoft.Bing/accounts@2020-06-10"
  name                      = "bing-${local.resource_token}"
  parent_id                 = azurerm_resource_group.main.id
  location                  = "global"
  tags                      = local.tags
  schema_validation_enabled = false

  body = {
    kind = "Bing.Grounding"
    sku = {
      name = "G1"
    }
    properties = {
      statisticsEnabled = false
    }
  }

  response_export_values = ["*"]
}

resource "azapi_resource_action" "bing_keys" {
  count = !var.use_existing_ai_project && local.has_bing ? 1 : 0

  type                   = "Microsoft.Bing/accounts@2020-06-10"
  resource_id            = azapi_resource.bing[0].id
  action                 = "listKeys"
  method                 = "POST"
  response_export_values = ["*"]
}

resource "azurerm_role_assignment" "project_bing_user" {
  count = !var.use_existing_ai_project && local.has_bing ? 1 : 0

  scope                = azapi_resource.bing[0].id
  role_definition_name = "Cognitive Services User"
  principal_id         = local.project_principal_id
  principal_type       = "ServicePrincipal"
}

resource "azapi_resource" "bing_custom" {
  count = !var.use_existing_ai_project && local.has_bing_custom ? 1 : 0

  type                      = "Microsoft.Bing/accounts@2020-06-10"
  name                      = "bingcustom-${local.resource_token}"
  parent_id                 = azurerm_resource_group.main.id
  location                  = "global"
  tags                      = local.tags
  schema_validation_enabled = false

  body = {
    kind = "Bing.CustomGrounding"
    sku = {
      name = "G1"
    }
    properties = {
      statisticsEnabled = false
    }
  }

  response_export_values = ["*"]
}

resource "azapi_resource_action" "bing_custom_keys" {
  count = !var.use_existing_ai_project && local.has_bing_custom ? 1 : 0

  type                   = "Microsoft.Bing/accounts@2020-06-10"
  resource_id            = azapi_resource.bing_custom[0].id
  action                 = "listKeys"
  method                 = "POST"
  response_export_values = ["*"]
}

resource "azurerm_role_assignment" "project_bing_custom_user" {
  count = !var.use_existing_ai_project && local.has_bing_custom ? 1 : 0

  scope                = azapi_resource.bing_custom[0].id
  role_definition_name = "Cognitive Services User"
  principal_id         = local.project_principal_id
  principal_type       = "ServicePrincipal"
}