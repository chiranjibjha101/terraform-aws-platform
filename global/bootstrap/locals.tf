locals {
  # Bucket names must be globally unique across all AWS accounts
  # Pattern: {org}-tfstate-{account_id}-{region}
  state_bucket_name = "${var.org}-tfstate-${var.account_id}-${var.region}"
  log_bucket_name   = "${var.org}-tfstate-logs-${var.account_id}-${var.region}"
}
