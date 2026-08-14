locals {
  tags = {
    azd-env-name = var.environment_name
  }

  resource_token = substr(sha1("${var.subscription_id}/${var.resource_group_name}/${var.location}"), 0, 13)

  deployments                 = jsondecode(var.ai_project_deployments_json)
  requested_connections       = jsondecode(var.ai_project_connections_json)
  connection_credentials      = jsondecode(var.ai_project_connection_credentials_json)
  requested_dependent         = jsondecode(var.ai_project_dependent_resources_json)
  dependent_resources_by_type = { for item in local.requested_dependent : item.resource => item }

  has_storage     = contains(keys(local.dependent_resources_by_type), "storage")
  has_search      = contains(keys(local.dependent_resources_by_type), "azure_ai_search")
  has_bing        = contains(keys(local.dependent_resources_by_type), "bing_grounding")
  has_bing_custom = contains(keys(local.dependent_resources_by_type), "bing_custom_grounding")

  generated_acr_connection_name  = "acr-${local.resource_token}"
  generated_acr_resource_id      = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.ContainerRegistry/registries/cr${local.resource_token}"
  generated_appi_connection_name = "appi-${local.resource_token}"
  generated_appi_resource_id     = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Insights/components/appi-${local.resource_token}"

  has_existing_acr = (
    var.existing_container_registry_resource_id != "" &&
    lower(var.existing_container_registry_resource_id) != lower(local.generated_acr_resource_id)
  )
  has_existing_acr_link = (
    var.existing_acr_connection_name != "" &&
    var.existing_acr_connection_name != local.generated_acr_connection_name
  )
  has_existing_appi_link = (
    var.existing_app_insights_connection_name != "" &&
    var.existing_app_insights_connection_name != local.generated_appi_connection_name
  )
  has_existing_appi_value = (
    var.existing_application_insights_connection_string != "" &&
    var.existing_application_insights_resource_id != "" &&
    lower(var.existing_application_insights_resource_id) != lower(local.generated_appi_resource_id)
  )

  should_create_acr = (
    var.enable_hosted_agents &&
    !var.skip_acr &&
    !local.has_existing_acr &&
    !local.has_existing_acr_link
  )

  should_create_monitoring = (
    !var.use_existing_ai_project &&
    var.enable_monitoring &&
    !local.has_existing_appi_link &&
    !local.has_existing_appi_value
  )

  should_connect_existing_appi = (
    !var.use_existing_ai_project &&
    var.enable_monitoring &&
    local.has_existing_appi_value &&
    !local.has_existing_appi_link &&
    var.existing_application_insights_resource_id != ""
  )

  account_name = var.use_existing_ai_project ? var.ai_foundry_resource_name : (
    var.ai_foundry_resource_name != "" ? var.ai_foundry_resource_name : "ai-account-${local.resource_token}"
  )

  account_id = var.use_existing_ai_project ? data.azapi_resource.existing_ai_account[0].id : azapi_resource.ai_account[0].id
  project_id = var.use_existing_ai_project ? data.azapi_resource.existing_ai_project[0].id : azapi_resource.ai_project[0].id

  account_output = var.use_existing_ai_project ? data.azapi_resource.existing_ai_account[0].output : azapi_resource.ai_account[0].output
  project_output = var.use_existing_ai_project ? data.azapi_resource.existing_ai_project[0].output : azapi_resource.ai_project[0].output

  project_principal_id = try(local.project_output.identity.principalId, "")
  foundry_project_endpoint = try(
    local.project_output.properties.endpoints["AI Foundry API"],
    ""
  )
  azure_openai_endpoint = try(
    local.account_output.properties.endpoints["OpenAI Language Model Instance API"],
    ""
  )

  acr_connection_name = local.should_create_acr ? local.generated_acr_connection_name : (
    local.has_existing_acr_link ? var.existing_acr_connection_name : (
      local.has_existing_acr ? "acr-${local.resource_token}" : ""
    )
  )

  acr_login_server = local.should_create_acr ? azurerm_container_registry.main[0].login_server : var.existing_container_registry_endpoint
}