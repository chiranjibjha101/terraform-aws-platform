output "state_bucket_name" {
  description = "S3 bucket name for Terraform remote state — use in all other stacks' backend.tf"
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "S3 bucket ARN — use in IAM policies granting state access"
  value       = aws_s3_bucket.state.arn
}

output "kms_key_arn" {
  description = "KMS key ARN for state encryption — use in all other stacks' backend.tf"
  value       = aws_kms_key.state.arn
}

output "kms_key_id" {
  description = "KMS key ID — use when referencing the key within this account"
  value       = aws_kms_key.state.key_id
}

output "region" {
  description = "Region where bootstrap resources were created"
  value       = var.region
}

output "backend_config" {
  description = "Complete backend block to paste into every other stack's backend.tf"
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket         = "${aws_s3_bucket.state.id}"
        key            = "<stack>/<env>/terraform.tfstate"
        region         = "${var.region}"
        encrypt        = true
        use_lockfile = true
      }
    }
  EOT
}
