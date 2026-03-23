output "role_arn" {
  description = "The ARN of the IAM role. Use this in KMS key policies, S3 bucket policies, or any resource-based policy."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "The name of the IAM role. Use this for aws_iam_role_policy_attachment or referencing in other modules."
  value       = aws_iam_role.this.name
}

output "role_id" {
  description = "The unique ID of the IAM role."
  value       = aws_iam_role.this.unique_id
}
