# -----------------------------------------------------------------------------
# IAM Role Module
# Creates an IAM role with flexible trust policy supporting AWS principals,
# service principals, and OIDC federation (IRSA / GitHub Actions).
# -----------------------------------------------------------------------------

# --- Trust Policy ---
# Builds the AssumeRole trust policy dynamically from structured inputs.
# This is safer than accepting raw JSON — prevents overly permissive trust.

data "aws_iam_policy_document" "trust" {

  # AWS principal trust — for cross-account roles, other IAM roles/users
  dynamic "statement" {
    for_each = length(var.trusted_role_arns) > 0 ? [1] : []
    content {
      sid     = "AllowAssumeByAWSPrincipals"
      effect  = "Allow"
      actions = ["sts:AssumeRole"]

      principals {
        type        = "AWS"
        identifiers = var.trusted_role_arns
      }
    }
  }

  # Service principal trust — for AWS services (ECS, Lambda, etc.)
  dynamic "statement" {
    for_each = length(var.trusted_role_services) > 0 ? [1] : []
    content {
      sid     = "AllowAssumeByServices"
      effect  = "Allow"
      actions = ["sts:AssumeRole"]

      principals {
        type        = "Service"
        identifiers = var.trusted_role_services
      }
    }
  }

  # OIDC federation trust — for IRSA (EKS pods) and GitHub Actions
  # Each provider gets its own statement with scoped conditions
  dynamic "statement" {
    for_each = var.trusted_oidc_providers
    content {
      sid     = "AllowAssumeByOIDC${statement.key}"
      effect  = "Allow"
      actions = ["sts:AssumeRoleWithWebIdentity"]

      principals {
        type        = "Federated"
        identifiers = [statement.value.provider_arn]
      }

      # StringEquals conditions — exact match (e.g., specific ServiceAccount)
      dynamic "condition" {
        for_each = length(statement.value.conditions_string_equals) > 0 ? [1] : []
        content {
          test     = "StringEquals"
          variable = statement.value.condition_variable
          values   = statement.value.conditions_string_equals
        }
      }

      # StringLike conditions — wildcard match (e.g., any SA in a namespace)
      dynamic "condition" {
        for_each = length(statement.value.conditions_string_like) > 0 ? [1] : []
        content {
          test     = "StringLike"
          variable = statement.value.condition_variable
          values   = statement.value.conditions_string_like
        }
      }
    }
  }
}

# --- IAM Role ---

resource "aws_iam_role" "this" {
  name                  = var.name
  description           = var.description
  path                  = var.path
  max_session_duration  = var.max_session_duration
  permissions_boundary  = var.permissions_boundary
  force_detach_policies = var.force_detach_policies
  assume_role_policy    = data.aws_iam_policy_document.trust.json

  tags = var.tags
}

# --- Managed Policy Attachments ---
# Attaches AWS-managed or customer-managed policies by ARN.
# for_each ensures each attachment is independently tracked in state.

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(var.managed_policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

# --- Inline Policies ---
# For one-off policies that don't need to be shared across roles.
# Map key = policy name, value = policy JSON document.

resource "aws_iam_role_policy" "inline" {
  for_each = var.inline_policies

  name   = each.key
  role   = aws_iam_role.this.name
  policy = each.value
}
