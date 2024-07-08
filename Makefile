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
env: bootstrap secrets compose logs
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
	@docker compose -f $(DOCKER_DIR)/compose.yaml down -v
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
secrets: secrets-prune secrets-dir
# ref: https://github.com/coreos/docs/blob/master/os/generate-self-signed-certificates.md
	$(call log_success, "Creating CA certificate for $(PROJ_NAME) Docker compose project!")
	cd $(SECRETS_TLS_DIR) && \
		cfssl genkey -initca $(CONFIG_TLS_DIR)/cfssl.json | cfssljson -bare ca
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

.PHONY: dist-dir
dist-dir:
	$(call log_notice, "Creating distribution directory for Helm charts at: $(OUT_DIR)")
	@mkdir -p $(OUT_DIR)

.PHONY: secrets-dir
secrets-dir:
	$(call log_notice, "Creating directory for secrets at: $(SECRETS_DIR)")
	@mkdir -p $(SECRETS_DIR)
	@mkdir -p $(SECRETS_TLS_DIR)

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