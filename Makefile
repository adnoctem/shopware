# Copyright (C) 2024 The FMJ Studios Shopware 6 Authors
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

DBG_MAKEFILE ?=
ifeq ($(DBG_MAKEFILE),1)
$(warning ***** starting Makefile for goal(s) "$(MAKECMDGOALS)")
$(warning ***** $(shell date))
else
# If we're not debugging the Makefile, don't echo recipes.
MAKEFLAGS += -s
endif

# -------------------------------------
# Configuration
# -------------------------------------

SHELL := /bin/bash

export ROOT_DIR = $(shell git rev-parse --show-toplevel)
export PROJ_NAME = $(shell basename "$(ROOT_DIR)")

# Only export variables from here since we do not want to mix the top-level
# Makfile's notion of 'SOURCES' with the different sub-makes
export

# ---------------------------
# Constants
# ---------------------------

SCRIPT_DIR := $(ROOT_DIR)/scripts
CONFIG_DIR := $(ROOT_DIR)/config
CONFIG_TLS_DIR := $(ROOT_DIR)/config/ssl
SECRETS_DIR := $(ROOT_DIR)/secrets
SECRETS_TLS_DIR := $(ROOT_DIR)/secrets/ssl
DOCKER_DIR := $(ROOT_DIR)/docker
CI_DIR := $(ROOT_DIR)/.github

# Documentation
DOCS_DIR := $(ROOT_DIR)/docs
MARKDOWNLINT_CONFIG := $(CI_DIR)/linters/.markdown-lint.yml

DATE := $(shell date '+%d.%m.%y-%T')
VERSION := $(shell composer show --self | grep 'versions' | grep -o -E '\*\s.+' | cut -d' ' -f 2)

# Executables
helmfile := helmfile
kind := kind
node := node
cfssl := cfssl

EXECUTABLES := $(helmfile) $(kind) $(node) $(cfssl)

# ---------------------------
# User-defined variables
# ---------------------------
PRINT_HELP ?=
TAG ?= v$(VERSION)

# ---------------------------
# Custom functions
# ---------------------------

define log
 @case ${2} in \
  gray)    echo -e "\e[90m${1}\e[0m" ;; \
  red)     echo -e "\e[91m${1}\e[0m" ;; \
  green)   echo -e "\e[92m${1}\e[0m" ;; \
  yellow)  echo -e "\e[93m${1}\e[0m" ;; \
  *)       echo -e "\e[97m${1}\e[0m" ;; \
 esac
endef

define log_info
 $(call log, $(1), "gray")
endef

define log_success
 $(call log, $(1), "green")
endef

define log_notice
 $(call log, $(1), "yellow")
endef

define log_attention
 $(call log, $(1), "red")
endef

# ---------------------------
#   Development Environment
# ---------------------------

define INIT_INFO
# Initialize the needed files to operate the project.
endef
.PHONY: init
ifeq ($(INIT_HELP), y)
init:
	echo "$$INIT_INFO"
else
init: dotenv secrets
endif

define ENV_INFO
# Create a local development environment for Helm charts. This is a wrapper
# target which requires the 'dev-cluster' and 'dev-cluster-bootstrap' Make
# targets.
endef
.PHONY: env
ifeq ($(PRINT_HELP), y)
env:
	echo "$$ENV_INFO"
else
env: bootstrap compose logs
endif

define ENV_INFO
# Create a local development environment for Helm charts. This is a wrapper
# target which requires the 'dev-cluster' and 'dev-cluster-bootstrap' Make
# targets.
endef
.PHONY: prune
ifeq ($(PRINT_HELP), y)
prune:
	echo "$$ENV_INFO"
else
prune:
	@docker compose -f compose.yaml down -v
	@$(SCRIPT_DIR)/hosts.sh remove
endif

# ---------------------------
#   Shopware Targets
# ---------------------------

define IMAGE_INFO
# Build a Docker image.
endef
.PHONY: image
ifeq ($(PRINT_HELP), y)
image:
	echo "$$IMAGE_INFO"
else
image:
	docker buildx build -f docker/Dockerfile -t fmjstudios/shopware:$(TAG) .
endif

# ---------------------------
#   Secrets
# ---------------------------
define SECRETS_INFO
# Create the secret files required to run the compose project. This creates a CA certificate
# with Cloudflare's CLI utility `cfssl`.
#
# Arguments:
#	PRINT_HELP: 'y' or 'n'
endef
.PHONY: secrets
ifeq ($(PRINT_HELP), y)
secrets:
	echo "$$SECRETS_INFO"
else
secrets: secrets-dir secrets-gen-ca secrets-gen-server
endif

define SECRETS_PRUNE_INFO
# Delete the previously created secret files from the repository. This will deleted
# all temporary folders created before and ask for confirmation to delete the contents
# of the main secrets folder
#
# Arguments:
#	PRINT_HELP: 'y' or 'n'
endef
.PHONY: secrets-prune
ifeq ($(PRINT_HELP), y)
secrets-prune:
	echo "$$SECRETS_PRUNE_INFO"
else
secrets-prune:
	$(call log_success, "Removing local secrets in $(SECRETS_DIR)!")
	rm -rf $(SECRETS_DIR)
endif

# ---------------------------
#   Dependencies
# ---------------------------

.PHONY: bootstrap
bootstrap:
	$(call log_scuess, "Bootstrapping Docker compose project")
	$(SCRIPT_DIR)/hosts.sh add

.PHONY: compose
compose:
	$(call log_success, "Starting Docker Compose")
	@docker compose -f compose.yaml up -d
	@sleep 5

.PHONY: logs
logs:
	@docker logs -f $(shell docker ps -aq -f 'label=application=shopware')

.PHONY: dotenv
dotenv:
ifeq ($(shell test -e .env && echo -n yes), yes)
	$(call log_attention, "Skipping generation of .env for Shopware. File exists!")
else
	$(call log_notice, "Generating .env for Shopware configuration from template")
	@cp .env.template .env
	@sed -i -e "s/APP_SECRET=CHANGEME/APP_SECRET=$(shell head -c 512 /dev/urandom | LC_CTYPE=C tr -cd 'a-zA-Z0-9' | head -c 48)/g" .env
	@sed -i -e "s/INSTANCE_ID=CHANGEME/INSTANCE_ID=$(shell head -c 512 /dev/urandom | LC_CTYPE=C tr -cd 'a-zA-Z0-9' | head -c 32)/g" .env
endif


.PHONY: secrets-dir
secrets-dir:
	$(call log_notice, "Creating directory for secrets at: $(SECRETS_DIR)")
	@mkdir -p $(SECRETS_DIR)
	@mkdir -p $(SECRETS_TLS_DIR)

# ref: https://github.com/coreos/docs/blob/master/os/generate-self-signed-certificates.md
.PHONY: secrets-gen-ca
secrets-gen-ca:
ifeq ($(shell test -e $(SECRETS_TLS_DIR)/ca.pem && echo -n yes ), yes)
	$(call log_attention, "Skipping generation of root certificate authority. Files exist!")
else
	$(call log_notice, "Generating root certificate authority at: $(SECRETS_DIR)")
	@cd $(SECRETS_TLS_DIR) && \
    	cfssl genkey -initca $(CONFIG_TLS_DIR)/ca-csr.json | cfssljson -bare ca
endif

# ref: https://github.com/coreos/docs/blob/master/os/generate-self-signed-certificates.md
.PHONY: secrets-gen-server
secrets-gen-server:
ifeq ($(shell test -e $(SECRETS_TLS_DIR)/server.pem && echo -n yes ), yes)
	$(call log_attention, "Skipping generation of server TLS certificate. Files exist!")
else
	$(call log_notice, "Generating server TLS certificate at: $(SECRETS_DIR)")
	@cd $(SECRETS_TLS_DIR) && \
    	cfssl gencert -ca=$(SECRETS_TLS_DIR)/ca.pem -ca-key=$(SECRETS_TLS_DIR)/ca-key.pem \
    	-config=$(CONFIG_TLS_DIR)/ca-config.json -profile=server $(CONFIG_TLS_DIR)/server-csr.json \
    	 | cfssljson -bare server
endif

# ---------------------------
# Linting
# ---------------------------
.PHONY: lint
lint: markdownlint actionlint shellcheck shfmt gitleaks

.PHONY: markdownlint
markdownlint:
	@markdownlint -c $(MARKDOWNLINT_CONFIG) '**/*.md' --ignore 'vendor'

.PHONY: actionlint
actionlint:
	@actionlint

.PHONY: gitleaks
gitleaks:
	@gitleaks detect --no-banner --no-git --redact --config $(GITLEAKS_CONFIG) --verbose --source .

.PHONY: shellcheck
shellcheck:
	@shellcheck scripts/**/*.sh -x

.PHONY: shfmt
shfmt:
	@shfmt -d .