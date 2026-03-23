variable "org" {
  type        = string
  description = "Organization Name"
}

variable "account_id" {
  type        = string
  description = "Aws Account Id"
}

variable "region" {
  type        = string
  description = "Aws Region"
}

variable "log_retention_days" {
  type        = number
  description = "Log retestion Days"
}

variable "state_version_expiry_days" {
  type        = number
  description = "State Version expiry days "
}
