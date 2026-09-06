# ==============================================================================
# AWS & LOCALSTACK INFRASTRUCTURE MAKEFILE
# ==============================================================================

.PHONY: help init up down status backend tf-init plan apply scan lint audit act-test clean destroy

ENV ?= dev
TF_DIR := environments/dev
VENV := .venv
ACTIVATE := . $(VENV)/bin/activate

help: ## Display available targets
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Initialize virtual environment and dependencies
	python3 -m venv $(VENV)
	$(ACTIVATE) && pip install --upgrade pip
	$(ACTIVATE) && pip install terraform-local boto3 flake8 black

up: init ## Boot up LocalStack container and bootstrap S3/DynamoDB state backend
	docker-compose up -d
	@echo "[*] Waiting for LocalStack gateway..."
	@until curl -s http://localhost:4566/_localstack/health | grep -q '"s3": "available"\|"s3": "running"'; do \
		sleep 2; \
	done
	@echo "[+] LocalStack is healthy!"
	$(ACTIVATE) && python3 scripts/init_backend.py

down: ## Stop LocalStack containers
	docker-compose down

status: ## Check health status of LocalStack AWS services
	@curl -s http://localhost:4566/_localstack/health | python3 -m json.tool

tf-init: up ## Initialize Terraform using tflocal
	$(ACTIVATE) && cd $(TF_DIR) && tflocal init -reconfigure

plan: tf-init ## Generate execution plan via tflocal
	$(ACTIVATE) && cd $(TF_DIR) && tflocal plan -out=tfplan

apply: plan ## Apply Terraform infrastructure plan locally
	$(ACTIVATE) && cd $(TF_DIR) && tflocal apply -auto-approve tfplan
	@rm -f $(TF_DIR)/tfplan

scan: ## Run Trivy static security scan on IaC
	docker run --rm -v $(PWD):/src aquasec/trivy:latest config /src --severity HIGH,CRITICAL

lint: init ## Format check and validate Terraform & Python scripts
	$(ACTIVATE) && cd $(TF_DIR) && tflocal fmt -check
	$(ACTIVATE) && cd $(TF_DIR) && tflocal validate


audit: ## Execute Python runtime compliance guardrails (S3 WORM, KMS, SG Chaining)
	$(ACTIVATE) && python3 scripts/guardrails.py
	$(ACTIVATE) && python3 scripts/shift_right_audit.py


act-test: ## Test GitHub Actions workflow locally using nektos/act
	act -W .github/workflows/deploy.yml --container-architecture linux/amd64

destroy: ## Destroy provisioned LocalStack AWS resources
	$(ACTIVATE) && cd $(TF_DIR) && tflocal destroy -auto-approve

clean: down ## Wipe container volumes, virtualenv, and build artifacts
	rm -rf $(VENV)
	find . -type d -name "__pycache__" -exec rm -rf {} +
	rm -f $(TF_DIR)/tfplan
	rm -f $(TF_DIR)/localstack_providers_override.tf
	rm -rf $(TF_DIR)/.terraform/
