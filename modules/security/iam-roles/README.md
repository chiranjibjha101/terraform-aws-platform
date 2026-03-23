# iam-roles

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | 1.14.7 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 6.37.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.37.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/6.37.0/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.inline](https://registry.terraform.io/providers/hashicorp/aws/6.37.0/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.managed](https://registry.terraform.io/providers/hashicorp/aws/6.37.0/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_policy_document.trust](https://registry.terraform.io/providers/hashicorp/aws/6.37.0/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_description"></a> [description](#input\_description) | Description of the IAM role as viewed in AWS console. | `string` | `"Managed by Terraform"` | no |
| <a name="input_force_detach_policies"></a> [force\_detach\_policies](#input\_force\_detach\_policies) | Whether to force detaching any policies the role has before destroying it. Set to true to prevent destroy errors. | `bool` | `true` | no |
| <a name="input_inline_policies"></a> [inline\_policies](#input\_inline\_policies) | Map of inline policy name to policy JSON document. Use for one-off policies that don't need to be shared across roles. | `map(string)` | `{}` | no |
| <a name="input_managed_policy_arns"></a> [managed\_policy\_arns](#input\_managed\_policy\_arns) | List of ARNs of IAM managed policies to attach to the role. Can be AWS-managed (e.g. 'arn:aws:iam::aws:policy/ReadOnlyAccess') or customer-managed. | `list(string)` | `[]` | no |
| <a name="input_max_session_duration"></a> [max\_session\_duration](#input\_max\_session\_duration) | Maximum session duration in seconds when assuming this role. Default 1 hour. Range: 3600-43200 (1-12 hours). | `number` | `3600` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the IAM role. Should follow naming convention: {org}-{env}-{service}-role. | `string` | n/a | yes |
| <a name="input_path"></a> [path](#input\_path) | IAM path for organizational grouping (e.g. '/platform/', '/ci/'). Useful for IAM policy conditions that scope by path. | `string` | `"/"` | no |
| <a name="input_permissions_boundary"></a> [permissions\_boundary](#input\_permissions\_boundary) | ARN of the permissions boundary policy to attach. Limits the maximum permissions the role can ever have, regardless of attached policies. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags to assign to the IAM role. Stack-level default\_tags from the provider will still apply. | `map(string)` | `{}` | no |
| <a name="input_trusted_oidc_providers"></a> [trusted\_oidc\_providers](#input\_trusted\_oidc\_providers) | List of OIDC provider configurations for federated trust (IRSA, GitHub Actions).<br>Each entry creates a trust policy statement with AssumeRoleWithWebIdentity.<br><br>Example for IRSA:<br>  provider\_arn             = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/ABC123"<br>  condition\_variable       = "oidc.eks.us-east-1.amazonaws.com/id/ABC123:sub"<br>  conditions\_string\_equals = ["system:serviceaccount:app-namespace:my-service-account"]<br>  conditions\_string\_like   = []<br><br>Example for GitHub Actions:<br>  provider\_arn             = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"<br>  condition\_variable       = "token.actions.githubusercontent.com:sub"<br>  conditions\_string\_equals = []<br>  conditions\_string\_like   = ["repo:my-org/my-repo:*"] | <pre>list(object({<br>    provider_arn             = string       # ARN of the OIDC provider (EKS or GitHub)<br>    condition_variable       = string       # e.g. "oidc.eks.us-east-1.amazonaws.com/id/ABC123:sub"<br>    conditions_string_equals = list(string) # Exact match values (e.g. "system:serviceaccount:ns:sa")<br>    conditions_string_like   = list(string) # Wildcard match values (e.g. "system:serviceaccount:ns:*")<br>  }))</pre> | `[]` | no |
| <a name="input_trusted_role_arns"></a> [trusted\_role\_arns](#input\_trusted\_role\_arns) | List of AWS principal ARNs (IAM roles, users, accounts) that can assume this role. Used for cross-account access and role chaining. | `list(string)` | `[]` | no |
| <a name="input_trusted_role_services"></a> [trusted\_role\_services](#input\_trusted\_role\_services) | List of AWS service principals that can assume this role (e.g. 'ecs-tasks.amazonaws.com', 'lambda.amazonaws.com'). | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | The ARN of the IAM role. Use this in KMS key policies, S3 bucket policies, or any resource-based policy. |
| <a name="output_role_id"></a> [role\_id](#output\_role\_id) | The unique ID of the IAM role. |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | The name of the IAM role. Use this for aws\_iam\_role\_policy\_attachment or referencing in other modules. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
