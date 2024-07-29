# Copyright (C) [2024] The FMJ Studios Shopware 6 Authors
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

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
# Makefile's notion of 'SOURCES' with the different sub-makes
export

# ---------------------------
# Constants
# ---------------------------

SCRIPT_DIR := $(ROOT_DIR)/scripts
CONFIG_DIR := $(ROOT_DIR)/config
CONFIG_TLS_DIR := $(ROOT_DIR)/config/ssl
DOCS_DIR := $(ROOT_DIR)/docs
SECRETS_DIR := $(ROOT_DIR)/secrets
SECRETS_TLS_DIR := $(ROOT_DIR)/secrets/ssl
DEPENDENCY_DIR := $(ROOT_DIR)/vendor
DOCKER_DIR := $(ROOT_DIR)/docker
CI_DIR := $(ROOT_DIR)/.github
CI_LINTER_DIR := $(CI_DIR)/linters
PLUGIN_DIR := $(ROOT_DIR)/custom/plugins
APPS_DIR := $(ROOT_DIR)/custom/apps

# Configuration files
MARKDOWNLINT_CONFIG := $(CI_LINTER_DIR)/.markdown-lint.yml
GITLEAKS_CONFIG := $(CI_LINTER_DIR)/.gitleaks.toml
DOCKERFILE := $(DOCKER_DIR)/Dockerfile

FIND_FLAGS := -maxdepth 1 -mindepth 1 -type d -exec \basename {} \;
PLUGINS := $(shell find $(PLUGIN_DIR) $(FIND_FLAGS))
APPS := $(shell find $(APPS_DIR) $(FIND_FLAGS))


# general variables
IMAGE_NAME := fmjstudios/shopware

DATE := $(shell date '+%d.%m.%y-%T')
PROJ_VERSION := $(shell composer show --self | grep 'versions' | grep -o -E '\*\s.+' | cut -d' ' -f 2)

# Executables
php := php # at least version 8.2
composer := composer
kind := kind
node := node
cfssl := cfssl

EXECUTABLES := $(php) $(composer) $(kind) $(node) $(cfssl)

# ---------------------------
# User-defined variables
# ---------------------------
PRINT_HELP ?=
TAG ?= v$(VERSION)
STOP ?= n

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
# Initialize the project. This inserts the custom hostnames into /etc/hosts and generates
# the required files to operate the project. Specifically this generates the .env file as
# well as TLS certificates within the $(SECRETS_TLS_DIR) for use with Traefik to enable
# HTTPS for local development.
#
# See the target's prerequesites for information about the commands excuted.
endef
.PHONY: init
ifeq ($(PRINT_HELP), y)
init:
	echo "$$INIT_INFO"
else
init: bootstrap deps dotenv secrets image
endif

define ENV_INFO
# Manage the development environment for Shopware 6. This creates a local Docker Compose
# project using Traefik, which provides HTTPS access to all (public) services within the
# project. Finally the target will follow the Docker logs for the "shopware" container.
# If the "DESTROY" variable is set it will remove the environment.
#
# See the target's prerequesites for information about the commands excuted.
#
# Arguments:
#   PRINT_HELP: 'y' or 'n'
# 	STOP: 'y' or 'n'
endef
.PHONY: env
ifeq ($(PRINT_HELP), y)
env:
	echo "$$ENV_INFO"
else
env: compose logs
endif

define PRUNE_INFO
# Remove the local configuration

# Create a local development environment for Helm charts. This is a wrapper
# target which requires the 'dev-cluster' and 'dev-cluster-bootstrap' Make
# targets.
endef
.PHONY: prune
ifeq ($(PRINT_HELP), y)
prune:
	echo "$$PRUNE_INFO"
else
prune: prune-compose prune-bootstrap prune-secrets prune-dependencies
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
	docker buildx build -f $(DOCKERFILE) -t $(IMAGE_NAME):$(TAG) .
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

# ---------------------------
#   Dependencies
# ---------------------------

# setup
.PHONY: bootstrap
bootstrap:
	$(call log_success, "Bootstrapping Docker compose project")
	@$(SCRIPT_DIR)/hosts.sh add

.PHONY:
deps: deps-composer deps-npm

.PHONY: deps-composer
deps-composer: deps-composer-project deps-composer-plugins deps-composer-apps

.PHONY: deps-composer-project
.ONESHELL:
deps-composer-project:
	@(call log_sucess, "Install project Composer dependencies")
	@composer install

.PHONY: deps-composer-plugins
.ONESHELL:
deps-composer-plugins:
	@for plugin in $(PLUGINS); do
	echo "Installing Composer dependencies for plugin: $$plugin.";
	@composer install -d custom/plugins/$$plugin
	done

.PHONY: deps-composer-apps
.ONESHELL:
deps-composer-apps:
	@for app in $(APPS); do
	echo "Installing Composer dependencies for app: $$app.";
	@composer install -d custom/apps/$$plugin
	done

.PHONY: deps-npm
deps-npm: deps-npm-plugins deps-npm-apps

.PHONY: deps-npm-plugins
.ONESHELL:
deps-npm-plugins:
	@for plugin in $(PLUGINS); do
	if [[ -e custom/plugins/$$plugin/src/Resources/app/administration/package.json ]]; then
		echo "Installing plugin: $$plugin NPM dependencies";
		cd custom/plugins/$$plugin/src/Resources/app/administration;
		npm install --no-audit --no-fund --prefer-offline;
	else
		echo "Skipping NPM dependency installation for plugin: $$plugin"
	fi
	done

.PHONY: deps-npm-apps
.ONESHELL:
deps-npm-apps:
	@for app in $(APPS); do
	if [[ -e custom/apps/$$app/src/Resources/app/administration/package.json ]]; then
		echo "Installing plugin: $$plugin NPM dependencies";
		cd custom/apps/$$app/src/Resources/app/administration;
		npm install --no-audit --no-fund --prefer-offline;
	else
		echo "Skipping NPM dependency installation for app: $$app"
	fi
	done


.PHONY: compose
compose:
ifeq ($(STOP), n)
	$(call log_success, "Starting Docker Compose project")
	@docker compose -f compose.yaml up -d
	@sleep 5
else
	$(call log_attention, "Stopping Docker Compose project!")
	@docker compose -f compose.yaml down
endif

.PHONY: logs
logs:
	@docker logs -f $(shell docker ps -aq -f 'label=application=shopware')

# init
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

# secrets
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

# prune
.PHONY: prune-compose
prune-compose:
	$(call log_success, "Removing assets created by Docker Compose!")
	@docker compose -f compose.yaml down -v

.PHONY: prune-bootstrap
prune-bootstrap:
	$(call log_success, "Removing local bootstrapping files!")
	@$(SCRIPT_DIR)/hosts.sh remove

.PHONY: prune-secrets
prune-secrets:
	$(call log_success, "Removing local secrets in $(SECRETS_DIR)!")
	rm -rf $(SECRETS_DIR)

.PHONY: prune-dependencies
prune-dependencies:
	$(call log_success, "Removing local dependencies in $(DEPENDENCY_DIR)!")
	rm -rf $(DEPENDENCY_DIR)

# ---------------------------
# Checks
# ---------------------------

.PHONY: tools-check
tools-check:
	$(foreach exe,$(EXECUTABLES), $(if $(shell command -v $(exe) 2> /dev/null), $(info Found $(exe)), $(info Please install $(exe))))

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
	@shellcheck scripts/*.sh -x

.PHONY: shfmt
shfmt:
	@shfmt -d .