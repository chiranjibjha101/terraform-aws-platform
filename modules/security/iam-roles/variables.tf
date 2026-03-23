# -----------------------------------------------------------------------------
# Required Variables
# -----------------------------------------------------------------------------

variable "name" {
  type        = string
  description = "Name of the IAM role. Should follow naming convention: {org}-{env}-{service}-role."

  validation {
    condition     = length(var.name) <= 64
    error_message = "IAM role name must be 64 characters or fewer."
  }
}

# -----------------------------------------------------------------------------
# Trust Policy Variables
# At least one trust source must be provided — the role is useless without it.
# -----------------------------------------------------------------------------

variable "trusted_role_arns" {
  type        = list(string)
  description = "List of AWS principal ARNs (IAM roles, users, accounts) that can assume this role. Used for cross-account access and role chaining."
  default     = []
}

variable "trusted_role_services" {
  type        = list(string)
  description = "List of AWS service principals that can assume this role (e.g. 'ecs-tasks.amazonaws.com', 'lambda.amazonaws.com')."
  default     = []
}

variable "trusted_oidc_providers" {
  type = list(object({
    provider_arn             = string       # ARN of the OIDC provider (EKS or GitHub)
    condition_variable       = string       # e.g. "oidc.eks.us-east-1.amazonaws.com/id/ABC123:sub"
    conditions_string_equals = list(string) # Exact match values (e.g. "system:serviceaccount:ns:sa")
    conditions_string_like   = list(string) # Wildcard match values (e.g. "system:serviceaccount:ns:*")
  }))
  description = <<-EOT
    List of OIDC provider configurations for federated trust (IRSA, GitHub Actions).
    Each entry creates a trust policy statement with AssumeRoleWithWebIdentity.

    Example for IRSA:
      provider_arn             = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/ABC123"
      condition_variable       = "oidc.eks.us-east-1.amazonaws.com/id/ABC123:sub"
      conditions_string_equals = ["system:serviceaccount:app-namespace:my-service-account"]
      conditions_string_like   = []

    Example for GitHub Actions:
      provider_arn             = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
      condition_variable       = "token.actions.githubusercontent.com:sub"
      conditions_string_equals = []
      conditions_string_like   = ["repo:my-org/my-repo:*"]
  EOT
  default     = []
}

# -----------------------------------------------------------------------------
# Permission Variables
# -----------------------------------------------------------------------------

variable "managed_policy_arns" {
  type        = list(string)
  description = "List of ARNs of IAM managed policies to attach to the role. Can be AWS-managed (e.g. 'arn:aws:iam::aws:policy/ReadOnlyAccess') or customer-managed."
  default     = []
}

variable "inline_policies" {
  type        = map(string)
  description = "Map of inline policy name to policy JSON document. Use for one-off policies that don't need to be shared across roles."
  default     = {}
}

variable "permissions_boundary" {
  type        = string
  description = "ARN of the permissions boundary policy to attach. Limits the maximum permissions the role can ever have, regardless of attached policies."
  default     = null
}

# -----------------------------------------------------------------------------
# Role Configuration
# -----------------------------------------------------------------------------

variable "description" {
  type        = string
  description = "Description of the IAM role as viewed in AWS console."
  default     = "Managed by Terraform"
}

variable "path" {
  type        = string
  description = "IAM path for organizational grouping (e.g. '/platform/', '/ci/'). Useful for IAM policy conditions that scope by path."
  default     = "/"
}

variable "max_session_duration" {
  type        = number
  description = "Maximum session duration in seconds when assuming this role. Default 1 hour. Range: 3600-43200 (1-12 hours)."
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "Max session duration must be between 3600 (1 hour) and 43200 (12 hours) seconds."
  }
}

variable "force_detach_policies" {
  type        = bool
  description = "Whether to force detaching any policies the role has before destroying it. Set to true to prevent destroy errors."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to assign to the IAM role. Stack-level default_tags from the provider will still apply."
  default     = {}
}
