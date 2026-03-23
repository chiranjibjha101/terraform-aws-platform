# =============================================================================
# global/bootstrap/main.tf
#
# Plain resource blocks — no module calls, no abstraction.
# This is intentional. See the last answer for the reasoning.
#
# Resources created:
#   1. KMS key        — encrypts state files and DynamoDB lock table
#   2. S3 log bucket  — receives S3 access logs from the state bucket
#   3. S3 state bucket — stores all Terraform state for every stack
#   4. DynamoDB table — provides state locking (prevents concurrent applies)
# =============================================================================




# =============================================================================
# 1. KMS KEY — encrypts state bucket and DynamoDB lock table
# =============================================================================

resource "aws_kms_key" "state" {
  description             = "Encrypts Terraform remote state — ${var.org}"
  deletion_window_in_days = 30   # 30-day safety window before permanent deletion
  enable_key_rotation     = true # AWS rotates the key material annually
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableAccountRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowS3ServiceToUseKey"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name    = "${var.org}-tfstate-kms"
    Purpose = "terraform-state-encryption"
  }
}

resource "aws_kms_alias" "state" {
  name          = "alias/${var.org}-tfstate"
  target_key_id = aws_kms_key.state.key_id
}


# =============================================================================
# 2. S3 ACCESS LOG BUCKET — receives access logs from the state bucket
#    Created first because the state bucket references it
# =============================================================================
resource "aws_s3_bucket" "logs" {
  bucket        = local.log_bucket_name
  force_destroy = false

  tags = {
    Name    = local.log_bucket_name
    Purpose = "terraform-state-access-logs"
  }
  # checkov:skip=CKV2_AWS_62:Event Notification is not needed
  # checkov:skip=CKV_AWS_144:Cross Region Replication is not needed here
  # checkov:skip=CKV_AWS_21:Versoning is not needed here
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Suspended" # Logs do not need versioning
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.state.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Expire log objects after retention period — logs grow unboundedly otherwise
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    id     = "expire-logs"
    status = "Enabled"
    expiration {
      days = var.log_retention_days
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}
resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3LogDelivery"
        Effect = "Allow"
        Principal = {
          Service = "logging.s3.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs.arn}/state-bucket-logs/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.account_id
          }
        }
      },
      {
        Sid       = "DenyHTTP"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.logs.arn,
          "${aws_s3_bucket.logs.arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.logs]
}


# =============================================================================
# 3. S3 STATE BUCKET — stores all Terraform state files
# =============================================================================

resource "aws_s3_bucket" "state" {
  bucket        = local.state_bucket_name
  force_destroy = false # Prevents accidental deletion via terraform destroy

  tags = {
    Name    = local.state_bucket_name
    Purpose = "terraform-remote-state"
  }

  # Protects against terraform destroy removing the bucket
  # Remove this block only if you intentionally want to delete the bucket
  lifecycle {
    prevent_destroy = true
  }
  # checkov:skip=CKV2_AWS_62: Event Notification is not needed
  # checkov:skip=CKV_AWS_144: Cross Region Replication is not needed here
}

# Versioning — mandatory so you can recover from state corruption or bad applies
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption — CMK not AWS-managed key, so you control access to state data
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.state.arn
    }
    # Reduces the number of KMS API calls and therefore cost
    bucket_key_enabled = true
  }
}

# Block all public access — non-negotiable for a state bucket
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Access logging — every read/write to the state bucket is logged
resource "aws_s3_bucket_logging" "state" {
  bucket        = aws_s3_bucket.state.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "state-bucket-logs/"

  depends_on = [aws_s3_bucket_policy.logs]
}

# Lifecycle — prevent unbounded storage growth from old state versions
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    # Delete non-current versions after N days
    noncurrent_version_expiration {
      noncurrent_days = var.state_version_expiry_days
    }

    # Clean up failed multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.state]
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Deny any request that is not over HTTPS
        Sid       = "DenyHTTP"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.state.arn,
          "${aws_s3_bucket.state.arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
      {
        Sid       = "DenyNonKMSUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.state.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },
      {
        Sid       = "DenyWrongKMSKey"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.state.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption-aws-kms-key-id" = aws_kms_key.state.arn
          }
        }
      }
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.state]
}
