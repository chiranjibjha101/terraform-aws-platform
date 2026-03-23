# ── STEP 1 & 2: Use this block on first run ───────────────────────────────────
# terraform {
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# }

# ── STEP 3 onwards: Uncomment after apply, then run: terraform init -migrate-state
terraform {
  backend "s3" {
    bucket       = "enterprise-org-tfstate-857385469724-ap-south-1"
    key          = "global/bootstrap/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    kms_key_id   = "11e6e08f-d38d-415b-802e-fd4989d49e2f"
    use_lockfile = true
  }
}
