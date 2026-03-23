# =============================================================================
# terraform-aws-platform — Makefile
# =============================================================================
# Usage:
#   make <target> STACK=<stack> ENV=<env>
#
# Examples:
#   make init    STACK=networking    ENV=dev
#   make plan    STACK=compute       ENV=staging
#   make apply   STACK=data          ENV=prod
#   make destroy STACK=networking    ENV=dev
#   make check                        (runs all checks across repo)
# =============================================================================

# ── Default values (override on CLI) ─────────────────────────────────────────
STACK     ?= networking
ENV       ?= dev
REGION    ?= us-east-1
ORG       ?= myorg

# ── Derived paths ─────────────────────────────────────────────────────────────
STACK_DIR  = stacks/$(STACK)/$(ENV)
GLOBAL_DIR = global

# ── Terraform binary (uses version from .terraform-version via tfenv) ─────────
TF         = terraform -chdir=$(STACK_DIR)
TF_GLOBAL  = terraform -chdir=$(GLOBAL_DIR)/bootstrap

# ── Colours for terminal output ───────────────────────────────────────────────
RED    = \033[0;31m
GREEN  = \033[0;32m
YELLOW = \033[0;33m
BLUE   = \033[0;34m
RESET  = \033[0m

# ── Guard: ensure STACK_DIR exists before running stack-level targets ─────────
guard-stack-dir:
	@if [ ! -d "$(STACK_DIR)" ]; then \
		echo "$(RED)ERROR: Directory $(STACK_DIR) does not exist.$(RESET)"; \
		echo "Valid stacks: networking compute data security observability dns-cdn"; \
		echo "Valid envs:   dev staging prod"; \
		exit 1; \
	fi

# ── Guard: require AWS credentials are set ───────────────────────────────────
guard-aws-creds:
	@if [ -z "$(AWS_PROFILE)" ] && [ -z "$(AWS_ACCESS_KEY_ID)" ]; then \
		echo "$(RED)ERROR: No AWS credentials found.$(RESET)"; \
		echo "Set AWS_PROFILE or export AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY"; \
		exit 1; \
	fi

# ── Guard: confirm destructive actions ───────────────────────────────────────
guard-destroy:
	@echo "$(RED)WARNING: You are about to DESTROY $(STACK)/$(ENV)$(RESET)"
	@echo "This will permanently delete all resources in this stack."
	@read -p "Type the stack name '$(STACK)' to confirm: " confirm && \
		[ "$$confirm" = "$(STACK)" ] || (echo "Aborted." && exit 1)


# =============================================================================
# SETUP — run once on a new machine or fresh clone
# =============================================================================

# ── Detect OS — used by setup target ─────────────────────────────────────────
UNAME := $(shell uname -s 2>/dev/null || echo Windows)

.PHONY: setup
setup: ## Install all required tools — detects macOS / Linux / Windows (WSL)
	@echo "$(BLUE)Detected OS: $(UNAME)$(RESET)"
	@if [ "$(UNAME)" = "Darwin" ]; then \
		echo "$(BLUE)macOS detected — installing via Homebrew...$(RESET)"; \
		which brew > /dev/null || (echo "$(RED)Homebrew not found. Install from https://brew.sh$(RESET)" && exit 1); \
		brew install tfenv tflint checkov pre-commit terraform-docs make; \
	elif [ "$(UNAME)" = "Linux" ]; then \
		echo "$(BLUE)Linux detected — installing via apt + pip + curl...$(RESET)"; \
		\
		echo "$(BLUE)  [1/5] Installing system packages...$(RESET)"; \
		sudo apt-get update -qq; \
		sudo apt-get install -y -qq git curl unzip make python3-pip; \
		\
		echo "$(BLUE)  [2/5] Installing tfenv...$(RESET)"; \
		if [ ! -d "$$HOME/.tfenv" ]; then \
			git clone --depth=1 https://github.com/tfutils/tfenv.git $$HOME/.tfenv; \
			echo 'export PATH="$$HOME/.tfenv/bin:$$PATH"' >> $$HOME/.bashrc; \
			echo 'export PATH="$$HOME/.tfenv/bin:$$PATH"' >> $$HOME/.zshrc 2>/dev/null || true; \
		else \
			echo "  tfenv already installed — skipping."; \
		fi; \
		export PATH="$$HOME/.tfenv/bin:$$PATH"; \
		\
		echo "$(BLUE)  [3/5] Installing tflint...$(RESET)"; \
		curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash; \
		\
		echo "$(BLUE)  [4/5] Installing checkov + pre-commit via pip...$(RESET)"; \
		pip3 install --quiet --upgrade checkov pre-commit; \
		\
		echo "$(BLUE)  [5/5] Installing terraform-docs...$(RESET)"; \
		TFDOCS_VERSION=v0.17.0; \
		curl -sSLo /tmp/terraform-docs.tar.gz \
			https://terraform-docs.io/dl/$${TFDOCS_VERSION}/terraform-docs-$${TFDOCS_VERSION}-linux-amd64.tar.gz; \
		tar -xzf /tmp/terraform-docs.tar.gz -C /tmp; \
		chmod +x /tmp/terraform-docs; \
		sudo mv /tmp/terraform-docs /usr/local/bin/terraform-docs; \
		rm -f /tmp/terraform-docs.tar.gz; \
	elif echo "$(UNAME)" | grep -qi "windows\|mingw\|msys\|cygwin"; then \
		echo "$(BLUE)Windows detected — installing via Chocolatey...$(RESET)"; \
		echo "$(YELLOW)NOTE: Run this in an elevated (Admin) PowerShell or Command Prompt.$(RESET)"; \
		which choco > /dev/null || \
			(echo "$(RED)Chocolatey not found. Install from https://chocolatey.org/install$(RESET)" && exit 1); \
		choco install -y terraform tflint python make; \
		pip install checkov pre-commit; \
		echo "$(YELLOW)terraform-docs: download manually from https://terraform-docs.io$(RESET)"; \
		echo "$(YELLOW)tfenv is not supported natively on Windows.$(RESET)"; \
		echo "$(YELLOW)Recommended: use WSL2 (Ubuntu) for the best Terraform experience on Windows.$(RESET)"; \
	else \
		echo "$(RED)Unrecognised OS: $(UNAME)$(RESET)"; \
		echo "Supported: macOS (Darwin), Linux, Windows (native or WSL)"; \
		exit 1; \
	fi
	@echo ""
	@echo "$(BLUE)Installing Terraform version from .terraform-version...$(RESET)"
	@export PATH="$$HOME/.tfenv/bin:$$PATH" && \
		which tfenv > /dev/null 2>&1 && tfenv install && tfenv use || \
		echo "$(YELLOW)tfenv not in PATH yet. Open a new terminal, then run: tfenv install && tfenv use$(RESET)"
	@echo ""
	@echo "$(BLUE)Installing pre-commit hooks into this repo...$(RESET)"
	@which pre-commit > /dev/null 2>&1 && pre-commit install || \
		echo "$(YELLOW)pre-commit not in PATH yet. Open a new terminal, then run: make hooks$(RESET)"
	@echo ""
	@echo "$(GREEN)Setup complete.$(RESET)"
	@echo "$(YELLOW)If tools are not found, open a new terminal to reload PATH, then run 'make version' to verify.$(RESET)"
	@echo "Run 'make help' to see all available commands."

.PHONY: setup-verify
setup-verify: ## Verify all required tools are installed and show their versions
	@echo "$(BLUE)Verifying tool installations...$(RESET)"
	@echo ""
	@which terraform    > /dev/null 2>&1 && echo "$(GREEN)  terraform     $(shell terraform version -json 2>/dev/null | python3 -c 'import sys,json; print(json.load(sys.stdin).get("terraform_version","ok"))' 2>/dev/null || terraform version | head -1)$(RESET)"     || echo "$(RED)  terraform     NOT FOUND$(RESET)"
	@which tfenv        > /dev/null 2>&1 && echo "$(GREEN)  tfenv         $(shell tfenv --version 2>&1)$(RESET)"        || echo "$(RED)  tfenv         NOT FOUND$(RESET)"
	@which tflint       > /dev/null 2>&1 && echo "$(GREEN)  tflint        $(shell tflint --version 2>&1 | head -1)$(RESET)"       || echo "$(RED)  tflint        NOT FOUND$(RESET)"
	@which checkov      > /dev/null 2>&1 && echo "$(GREEN)  checkov       $(shell checkov --version 2>&1)$(RESET)"      || echo "$(RED)  checkov       NOT FOUND$(RESET)"
	@which pre-commit   > /dev/null 2>&1 && echo "$(GREEN)  pre-commit    $(shell pre-commit --version 2>&1)$(RESET)"   || echo "$(RED)  pre-commit    NOT FOUND$(RESET)"
	@which terraform-docs > /dev/null 2>&1 && echo "$(GREEN)  terraform-docs $(shell terraform-docs --version 2>&1)$(RESET)" || echo "$(RED)  terraform-docs NOT FOUND$(RESET)"
	@which make         > /dev/null 2>&1 && echo "$(GREEN)  make          $(shell make --version | head -1)$(RESET)"         || echo "$(RED)  make          NOT FOUND$(RESET)"
	@echo ""

.PHONY: hooks
hooks: ## Install pre-commit hooks into this repo
	pre-commit install
	@echo "$(GREEN)Pre-commit hooks installed.$(RESET)"

.PHONY: run-hooks
run-hooks: ## Run all pre-commit hooks against all files right now
	pre-commit run --all-files


# =============================================================================
# BOOTSTRAP — run once per AWS account before any other stack
# =============================================================================

.PHONY: bootstrap-init
bootstrap-init: guard-aws-creds ## Init bootstrap with local backend (run first, ever)
	@echo "$(BLUE)Initialising bootstrap with local backend...$(RESET)"
	terraform -chdir=$(GLOBAL_DIR)/bootstrap init

.PHONY: bootstrap-apply
bootstrap-apply: guard-aws-creds ## Apply bootstrap — creates S3 state bucket + DynamoDB lock table
	@echo "$(YELLOW)Applying bootstrap — this creates your remote state infrastructure.$(RESET)"
	terraform -chdir=$(GLOBAL_DIR)/bootstrap apply -var="region=$(REGION)" -var="org=$(ORG)"

.PHONY: bootstrap-migrate
bootstrap-migrate: guard-aws-creds ## Migrate bootstrap local state → S3 after bucket is created
	@echo "$(BLUE)Migrating bootstrap state to S3...$(RESET)"
	terraform -chdir=$(GLOBAL_DIR)/bootstrap init -migrate-state


# =============================================================================
# CORE STACK TARGETS — init / plan / apply / destroy
# =============================================================================

.PHONY: init
init: guard-stack-dir guard-aws-creds ## terraform init for STACK/ENV
	@echo "$(BLUE)Initialising $(STACK)/$(ENV)...$(RESET)"
	$(TF) init -upgrade
	@echo "$(GREEN)Init complete: $(STACK_DIR)$(RESET)"

.PHONY: init-reconfigure
init-reconfigure: guard-stack-dir guard-aws-creds ## Force re-init (use when backend config changes)
	@echo "$(YELLOW)Re-configuring backend for $(STACK)/$(ENV)...$(RESET)"
	$(TF) init -reconfigure

.PHONY: validate
validate: guard-stack-dir ## terraform validate for STACK/ENV
	@echo "$(BLUE)Validating $(STACK)/$(ENV)...$(RESET)"
	$(TF) validate
	@echo "$(GREEN)Validation passed: $(STACK_DIR)$(RESET)"

.PHONY: plan
plan: guard-stack-dir guard-aws-creds ## terraform plan for STACK/ENV — saves plan to tfplan
	@echo "$(BLUE)Planning $(STACK)/$(ENV)...$(RESET)"
	$(TF) plan \
		-var-file=terraform.tfvars \
		-out=$(STACK_DIR)/tfplan \
		-detailed-exitcode; \
	EXIT=$$?; \
	if [ $$EXIT -eq 0 ]; then echo "$(GREEN)No changes. Infrastructure is up to date.$(RESET)"; \
	elif [ $$EXIT -eq 2 ]; then echo "$(YELLOW)Changes detected. Review above then run: make apply STACK=$(STACK) ENV=$(ENV)$(RESET)"; \
	else exit $$EXIT; fi

.PHONY: plan-destroy
plan-destroy: guard-stack-dir guard-aws-creds ## Show what destroy would remove, without doing it
	@echo "$(YELLOW)Destroy plan for $(STACK)/$(ENV)...$(RESET)"
	$(TF) plan -destroy -var-file=terraform.tfvars

.PHONY: apply
apply: guard-stack-dir guard-aws-creds ## terraform apply the saved tfplan for STACK/ENV
	@echo "$(BLUE)Applying $(STACK)/$(ENV)...$(RESET)"
	@if [ ! -f "$(STACK_DIR)/tfplan" ]; then \
		echo "$(RED)No tfplan found. Run 'make plan STACK=$(STACK) ENV=$(ENV)' first.$(RESET)"; \
		exit 1; \
	fi
	$(TF) apply $(STACK_DIR)/tfplan
	@rm -f $(STACK_DIR)/tfplan
	@echo "$(GREEN)Apply complete: $(STACK_DIR)$(RESET)"

.PHONY: apply-auto
apply-auto: guard-stack-dir guard-aws-creds ## Plan + apply in one step — use in CI only, not prod
	@echo "$(YELLOW)Auto-applying $(STACK)/$(ENV) — CI mode$(RESET)"
	$(TF) apply -var-file=terraform.tfvars -auto-approve

.PHONY: destroy
destroy: guard-stack-dir guard-aws-creds guard-destroy ## Destroy all resources in STACK/ENV
	@echo "$(RED)Destroying $(STACK)/$(ENV)...$(RESET)"
	$(TF) destroy -var-file=terraform.tfvars -auto-approve
	@echo "$(GREEN)Destroy complete: $(STACK_DIR)$(RESET)"

.PHONY: output
output: guard-stack-dir guard-aws-creds ## Show terraform outputs for STACK/ENV
	$(TF) output

.PHONY: state-list
state-list: guard-stack-dir guard-aws-creds ## List all resources in state for STACK/ENV
	$(TF) state list

.PHONY: state-show
state-show: guard-stack-dir guard-aws-creds ## Show details of a resource — usage: make state-show RESOURCE=aws_vpc.main
	$(TF) state show $(RESOURCE)

.PHONY: refresh
refresh: guard-stack-dir guard-aws-creds ## Refresh state against real infrastructure for STACK/ENV
	$(TF) refresh -var-file=terraform.tfvars

.PHONY: console
console: guard-stack-dir guard-aws-creds ## Open terraform console for STACK/ENV (useful for testing expressions)
	$(TF) console -var-file=terraform.tfvars


# =============================================================================
# FORMATTING
# =============================================================================

.PHONY: fmt
fmt: ## Format all .tf files recursively across the whole repo
	@echo "$(BLUE)Formatting all Terraform files...$(RESET)"
	terraform fmt -recursive
	@echo "$(GREEN)Formatting complete.$(RESET)"

.PHONY: fmt-check
fmt-check: ## Check formatting without modifying files — used in CI
	@echo "$(BLUE)Checking Terraform formatting...$(RESET)"
	terraform fmt -recursive -check
	@echo "$(GREEN)All files correctly formatted.$(RESET)"


# =============================================================================
# LINTING AND SECURITY
# =============================================================================

.PHONY: lint
lint: ## Run tflint across the entire repo
	@echo "$(BLUE)Running tflint...$(RESET)"
	tflint --recursive --config=.tflint.hcl
	@echo "$(GREEN)Linting passed.$(RESET)"

.PHONY: lint-stack
lint-stack: guard-stack-dir ## Run tflint against a single STACK/ENV
	@echo "$(BLUE)Linting $(STACK)/$(ENV)...$(RESET)"
	tflint --chdir=$(STACK_DIR) --config=../../../.tflint.hcl

.PHONY: security
security: ## Run checkov security scan across the repo
	@echo "$(BLUE)Running checkov security scan...$(RESET)"
	checkov -d . \
		--quiet \
		--framework terraform \
		--skip-check CKV_AWS_117,CKV_AWS_116
	@echo "$(GREEN)Security scan complete.$(RESET)"

.PHONY: security-stack
security-stack: guard-stack-dir ## Run checkov against a single STACK/ENV
	@echo "$(BLUE)Security scan: $(STACK)/$(ENV)...$(RESET)"
	checkov -d $(STACK_DIR) --quiet --framework terraform

.PHONY: docs
docs: ## Regenerate README.md for all modules using terraform-docs
	@echo "$(BLUE)Generating module documentation...$(RESET)"
	@find modules -name "*.tf" -not -path "*/.terraform/*" \
		-exec dirname {} \; | sort -u | while read dir; do \
		echo "  Generating docs for $$dir"; \
		terraform-docs markdown table --output-file README.md --output-mode inject "$$dir"; \
	done
	@echo "$(GREEN)Documentation generated.$(RESET)"


# =============================================================================
# COMPOSITE — run groups of checks together
# =============================================================================

.PHONY: check
check: fmt-check lint security ## Run all static checks — fmt, lint, security (no AWS calls)
	@echo "$(GREEN)All checks passed.$(RESET)"

.PHONY: check-stack
check-stack: guard-stack-dir ## Validate + lint + security for a single STACK/ENV
	@echo "$(BLUE)Running all checks for $(STACK)/$(ENV)...$(RESET)"
	$(MAKE) fmt-check
	$(MAKE) lint-stack    STACK=$(STACK) ENV=$(ENV)
	$(MAKE) security-stack STACK=$(STACK) ENV=$(ENV)
	$(MAKE) validate      STACK=$(STACK) ENV=$(ENV)
	@echo "$(GREEN)All checks passed for $(STACK)/$(ENV).$(RESET)"


# =============================================================================
# FULL ENVIRONMENT WORKFLOWS — deploy or destroy an entire environment
# =============================================================================

.PHONY: deploy-env
deploy-env: guard-aws-creds ## Deploy all stacks for ENV in dependency order
	@echo "$(BLUE)Deploying full environment: $(ENV)$(RESET)"
	$(MAKE) init  STACK=security      ENV=$(ENV)
	$(MAKE) apply-auto STACK=security ENV=$(ENV)
	$(MAKE) init  STACK=networking    ENV=$(ENV)
	$(MAKE) apply-auto STACK=networking ENV=$(ENV)
	$(MAKE) init  STACK=data          ENV=$(ENV)
	$(MAKE) apply-auto STACK=data     ENV=$(ENV)
	$(MAKE) init  STACK=compute       ENV=$(ENV)
	$(MAKE) apply-auto STACK=compute  ENV=$(ENV)
	$(MAKE) init  STACK=observability ENV=$(ENV)
	$(MAKE) apply-auto STACK=observability ENV=$(ENV)
	$(MAKE) init  STACK=dns-cdn       ENV=$(ENV)
	$(MAKE) apply-auto STACK=dns-cdn  ENV=$(ENV)
	@echo "$(GREEN)Environment $(ENV) fully deployed.$(RESET)"

.PHONY: destroy-env
destroy-env: guard-aws-creds ## Destroy all stacks for ENV in reverse dependency order
	@echo "$(RED)Destroying full environment: $(ENV)$(RESET)"
	@read -p "Type the environment name '$(ENV)' to confirm: " confirm && \
		[ "$$confirm" = "$(ENV)" ] || (echo "Aborted." && exit 1)
	$(MAKE) destroy STACK=dns-cdn       ENV=$(ENV)
	$(MAKE) destroy STACK=observability ENV=$(ENV)
	$(MAKE) destroy STACK=compute       ENV=$(ENV)
	$(MAKE) destroy STACK=data          ENV=$(ENV)
	$(MAKE) destroy STACK=networking    ENV=$(ENV)
	$(MAKE) destroy STACK=security      ENV=$(ENV)
	@echo "$(GREEN)Environment $(ENV) fully destroyed.$(RESET)"

# Practice-safe shortcut — destroys dev env, commonly used at end of sessions
.PHONY: destroy-dev
destroy-dev: guard-aws-creds ## Destroy entire dev environment — use after practice sessions
	$(MAKE) destroy-env ENV=dev


# =============================================================================
# DRIFT DETECTION — compare state vs real infrastructure
# =============================================================================

.PHONY: drift
drift: guard-stack-dir guard-aws-creds ## Detect drift for STACK/ENV (plan with no changes expected)
	@echo "$(BLUE)Checking for drift in $(STACK)/$(ENV)...$(RESET)"
	$(TF) plan -var-file=terraform.tfvars -detailed-exitcode -refresh=true; \
	EXIT=$$?; \
	if [ $$EXIT -eq 0 ]; then echo "$(GREEN)No drift detected.$(RESET)"; \
	elif [ $$EXIT -eq 2 ]; then echo "$(RED)DRIFT DETECTED in $(STACK)/$(ENV). Review the plan above.$(RESET)"; exit 2; \
	else exit $$EXIT; fi

.PHONY: drift-all
drift-all: guard-aws-creds ## Check drift across all prod stacks
	@echo "$(BLUE)Checking drift across all prod stacks...$(RESET)"
	@for stack in security networking data compute observability dns-cdn; do \
		echo ""; \
		echo "$(BLUE)--- Checking $$stack/prod ---$(RESET)"; \
		$(MAKE) drift STACK=$$stack ENV=prod || true; \
	done


# =============================================================================
# UTILITY
# =============================================================================

.PHONY: clean
clean: ## Remove all local .terraform dirs and plan files
	@echo "$(YELLOW)Cleaning up local Terraform state and plan files...$(RESET)"
	find . -type d -name ".terraform" -not -path "*/.git/*" | xargs rm -rf
	find . -name "tfplan" -not -path "*/.git/*" | xargs rm -f
	find . -name ".terraform.lock.hcl" -not -path "*/.git/*" | xargs rm -f
	@echo "$(GREEN)Clean complete.$(RESET)"

.PHONY: lock
lock: guard-stack-dir ## Update .terraform.lock.hcl for all platforms for STACK/ENV
	@echo "$(BLUE)Updating provider lock file for $(STACK)/$(ENV)...$(RESET)"
	$(TF) providers lock \
		-platform=linux_amd64 \
		-platform=linux_arm64 \
		-platform=darwin_amd64 \
		-platform=darwin_arm64
	@echo "$(GREEN)Lock file updated. Commit .terraform.lock.hcl to git.$(RESET)"

.PHONY: version
version: ## Show versions of all tools
	@echo "$(BLUE)Tool versions:$(RESET)"
	@terraform version
	@tflint --version
	@checkov --version
	@pre-commit --version
	@terraform-docs --version
	@make --version | head -1


# =============================================================================
# HELP
# =============================================================================

.PHONY: help
help: ## Show this help message
	@echo ""
	@echo "$(BLUE)terraform-aws-platform$(RESET)"
	@echo "$(BLUE)─────────────────────────────────────────────────────────────$(RESET)"
	@echo "Usage:  make <target> [STACK=<stack>] [ENV=<env>]"
	@echo ""
	@echo "$(YELLOW)STACK options:$(RESET)  networking  compute  data  security  observability  dns-cdn"
	@echo "$(YELLOW)ENV options:$(RESET)    dev  staging  prod"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; section=""} \
		/^# =/ { \
			gsub(/^# =+/, ""); gsub(/=+ *$$/, ""); \
			printf "\n$(YELLOW)%s$(RESET)\n", $$0 \
		} \
		/^[a-zA-Z_-]+:.*?##/ { \
			printf "  $(GREEN)%-22s$(RESET) %s\n", $$1, $$2 \
		}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(BLUE)Examples:$(RESET)"
	@echo "  make init    STACK=networking ENV=dev"
	@echo "  make plan    STACK=compute    ENV=staging"
	@echo "  make apply   STACK=data       ENV=prod"
	@echo "  make destroy STACK=networking ENV=dev"
	@echo "  make check"
	@echo "  make deploy-env ENV=dev"
	@echo "  make destroy-dev"
	@echo ""

# Default target when just running 'make' with no arguments
.DEFAULT_GOAL := help
