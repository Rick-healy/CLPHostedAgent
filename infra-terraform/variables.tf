variable "subscription_id" {
  type        = string
  description = "Azure subscription ID supplied by azd."
}

variable "environment_name" {
  type        = string
  description = "azd environment name used for resource naming and tags."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group to create or use."
}

variable "location" {
  type        = string
  description = "Primary Azure region."
}

variable "ai_deployments_location" {
  type        = string
  description = "Region for the Foundry account and model deployments."
}

variable "principal_id" {
  type        = string
  description = "Object ID of the user or service principal running the deployment."
}

variable "principal_type" {
  type        = string
  description = "Type of the deploying principal."
}

variable "ai_foundry_resource_name" {
  type        = string
  description = "Existing Foundry account name, or an optional name for a new account."
  default     = ""
}

variable "ai_foundry_project_name" {
  type        = string
  description = "Foundry project name."
}

variable "ai_project_deployments_json" {
  type        = string
  description = "JSON array of Foundry model deployments."
  default     = "[]"
}

variable "ai_project_connections_json" {
  type        = string
  description = "JSON array of Foundry project connections."
  default     = "[]"
}

variable "ai_project_connection_credentials_json" {
  type        = string
  description = "Sensitive JSON map of connection names to credential objects."
  default     = "{}"
  sensitive   = true
}

variable "ai_project_dependent_resources_json" {
  type        = string
  description = "JSON array of optional dependent resources."
  default     = "[]"
}

variable "enable_monitoring" {
  type        = bool
  description = "Create or connect Application Insights monitoring."
  default     = true
}

variable "enable_hosted_agents" {
  type        = bool
  description = "Create resources required for hosted agents."
  default     = false
}

variable "enable_capability_host" {
  type        = bool
  description = "Create the public Agents capability host."
  default     = true
}

variable "use_existing_ai_project" {
  type        = bool
  description = "Reference an existing Foundry account and project instead of creating them."
  default     = false
}

variable "existing_container_registry_resource_id" {
  type        = string
  description = "Optional resource ID of an existing Azure Container Registry."
  default     = ""
}

variable "existing_container_registry_endpoint" {
  type        = string
  description = "Optional login server of an existing Azure Container Registry."
  default     = ""
}

variable "existing_acr_connection_name" {
  type        = string
  description = "Optional existing Foundry ACR connection name."
  default     = ""
}

variable "skip_acr" {
  type        = bool
  description = "Skip ACR creation for code-deployment scenarios."
  default     = false
}

variable "existing_application_insights_connection_string" {
  type        = string
  description = "Optional connection string for an existing Application Insights resource."
  default     = ""
  sensitive   = true
}

variable "existing_application_insights_resource_id" {
  type        = string
  description = "Optional resource ID for existing Application Insights."
  default     = ""
}

variable "existing_app_insights_connection_name" {
  type        = string
  description = "Optional existing Foundry Application Insights connection name."
  default     = ""
}