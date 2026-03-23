variable "description" {
  type        = string
  description = "The description of the key as viewed in AWS console."
  default     = "Managed by Terraform"
}

variable "deletion_window_in_days" {
  type        = number
  description = "The waiting period, specified in number of days. After the waiting period ends, AWS KMS deletes the KMS key. Must be between 7 and 30."
  default     = 30

  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "Deletion window must be between 7 and 30 days."
  }
}

variable "enable_key_rotation" {
  type        = bool
  description = "Specifies whether annual key rotation is enabled. Defaults to true — no production justification to disable."
  default     = true
}

variable "multi_region" {
  type        = bool
  description = "Indicates whether the KMS key is a multi-Region key. Required for cross-region replica keys."
  default     = false
}

variable "policy" {
  type        = string
  description = "A valid KMS key policy JSON document. If null, AWS applies the default policy granting the account root full access. Service principals (e.g. rds.amazonaws.com) must be explicitly added when used with AWS services."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "A mapping of tags to assign to the KMS key. Stack-level default_tags from the provider will still apply."
  default     = {}
}

variable "alias" {
  type        = string
  description = "The logical name for the key alias. The module auto-prepends 'alias/' — pass only the name, e.g. 'platform-dev-rds'."

  validation {
    condition     = !startswith(var.alias, "alias/")
    error_message = "Do not include the 'alias/' prefix — the module adds it automatically."
  }
}
