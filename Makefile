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
OUTPUT_DIR := $(ROOT_DIR)/dist
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

COMPOSE_SUBNET := 172.25.0.0/16
COMPOSE_GATEWAY_IP := 172.25.0.1

# general variables
DATE := $(shell date '+%d.%m.%y-%T')
VERSION := $(shell composer show --self | grep 'versions' | grep -o -E '\*\s.+' | cut -d' ' -f 2)
NAME := $(shell composer show --self | grep 'names' | grep -o -E '\w+/\w+' | cut -d' ' -f 2)

# Executables
docker := docker
php := php # at least version 8.2
composer := composer
kind := kind # to be used later
node := node
cfssl := cfssl

EXECUTABLES := $(docker) $(php) $(composer) $(kind) $(node) $(cfssl)

# ---------------------------
# User-defined variables
# ---------------------------
PRINT_HELP ?=
TAG ?= v$(VERSION)
STOP ?= n
APP ?= shopware
CI ?= n

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
init: submodules bootstrap dotenv deps secrets
endif

define CI_INFO
# Initialize the project in CI mode.
#
# See the target's prerequesites for information about the commands excuted.
endef
.PHONY: ci
ifeq ($(PRINT_HELP), y)
ci:
	echo "$$CI_INFO"
else
ci: submodules deps
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
endef
.PHONY: env
ifeq ($(PRINT_HELP), y)
env:
	echo "$$ENV_INFO"
else
env: compose-network compose
endif

define ENV_CLEANUP_INFO
# Clean up the development environment for Shopware 6.
#
# Arguments:
#   PRINT_HELP: 'y' or 'n'
endef
.PHONY: env-cleanup
ifeq ($(PRINT_HELP), y)
env-cleanup:
	echo "$$ENV_CLEANUP_INFO"
else
env-cleanup:
	$(call log_attention, "Stopping Docker Compose project!")
	@$(docker) compose -f compose.yaml down -v
endif

define UPDATE_DEPS_INFO
# Update the Composer dependencies.
#
# Update the project's composer dependencies and develpoment dependencies.
endef
.PHONY: update-deps
ifeq ($(PRINT_HELP), y)
update-deps:
	echo "$$UPDATE_DEPS_INFO"
else
update-deps: update-base-deps update-dev-deps
endif

define TESTS_INFO
# Run each plugin or app's custom test suite via sub-makes.
endef
.PHONY: tests
ifeq ($(PRINT_HELP), y)
tests:
	echo "$$TESTS_INFO"
else
tests: tests-apps tests-plugins
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
prune: prune-output prune-secrets prune-deps prune-bootstrap prune-compose-network
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
	$(docker) buildx build -f $(DOCKERFILE) -t $(NAME):$(TAG) -t $(NAME):latest .
endif

define BUNDLE_INFO
# Build a Tarball bundle of the project's sources.
endef
.PHONY: bundle
ifeq ($(PRINT_HELP), y)
bundle:
	echo "$$BUNDLE_INFO"
else
bundle:
	tar -cvzf $(OUTPUT_DIR)/$(NAME)_$(VERSION).tar.gz .
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
	$(call log_success, "Bootstrapping host machine DNS entries!")
	@$(SCRIPT_DIR)/hosts.sh add

.PHONY: submodules
submodules:
	$(call log_success, "Pulling latest changes for all submodules!")
	@git pull --recurse-submodules --jobs=10

.PHONY: compose
compose:
	$(call log_success, "Starting Docker Compose project")
	@$(docker) compose -f compose.yaml up --build -d
	@sleep 5
	@$(MAKE) logs APP=shopware

.PHONY: compose-network
compose-network:
	$(call log_notice, "Creating Docker Compose networks")
	@$(docker) network rm public --force
	@$(docker) network create \
		--subnet $(COMPOSE_SUBNET) \
		--gateway $(COMPOSE_GATEWAY_IP) \
		public

.PHONY: deps
deps: deps-plugins deps-apps
	$(call log_sucess, "Install project Composer dependencies")
	@composer install

.PHONY: deps-plugins
.ONESHELL:
deps-plugins:
	@for plugin in $(PLUGINS); do
		echo "Installing dependencies for plugin: $$plugin"
		$(MAKE) -C custom/plugins/$$plugin deps
	done

.PHONY: deps-apps
.ONESHELL:
deps-apps:
	@for app in $(APPS); do
		echo "Installing dependencies for app: $$app"
		$(MAKE) -C apps/$$app deps
	done

.PHONY: logs
logs:
	@$(docker) logs -f $(shell docker ps -aq -f 'label=application=$(APP)')

.PHONY: tests-plugins
.ONESHELL:
tests-plugins:
	@for plugin in $(PLUGINS); do
		echo "Running test suite for plugin: $$plugin"
		$(MAKE) -C custom/plugins/$$plugin tests
	done

.PHONY: tests-apps
.ONESHELL:
tests-apps:
	@for app in $(APPS); do
		echo "Running test suite for app: $$app"
		$(MAKE) -C apps/$$app tests
	done

# Update dependencies
.PHONY: update-base-deps
update-base-deps:
	$(call log_notice, "Updating dependencies for $(APP)")
	@composer require $(shell composer show -s --format=json | jq '.requires | keys | map(.+" ") | add' -r)

.PHONY: update-dev-deps
update-dev-deps:
	$(call log_notice, "Updating development dependencies for $(APP)")
	@composer require --dev $(shell composer show -s --format=json | jq '.devRequires | keys | map(.+" ") | add' -r)

# ---------------------------
# Credentials & Secrets
# ---------------------------

# Generate the Symfony projects local '.env' file to configure the project
.PHONY: dotenv
dotenv:
ifeq ($(shell test -e .env && echo -n yes), yes)
	$(call log_attention, "Skipping generation of .env for Shopware. File exists!")
else
	$(call log_notice, "Generating .env for Shopware configuration from template")
	@cp .env.template .env
	@sed -i -e "s/APP_SECRET=CHANGEME/APP_SECRET=$(shell head -c 512 /dev/urandom | LC_CTYPE=C tr -cd 'a-zA-Z0-9' | head -c 48)/g" .env
	@sed -i -e "s/INSTANCE_ID=CHANGEME/INSTANCE_ID=$(shell head -c 512 /dev/urandom | LC_CTYPE=C tr -cd 'a-zA-Z0-9' | head -c 32)/g" .env
ifeq ($(CI), y)
	$(call log_notice, "Updating .env for Shopware CI")
	@sed -i -e "s/DATABASE_URL=mysql://shopware:shopware@mysql:3306/shopware/DATABASE_URL=mysql://shopware:shopware@loca:3306/shopware/g" .env
	@sed -i -e "s/OPENSEARCH_URL=http://opensearch:9200/OPENSEARCH_URL=http://localhost:9200/g" .env
	@sed -i -e "s/MAILER_DSN=smtp://shopware:shopware@mailpit:1025/MAILER_DSN=smtp://shopware:shopware@localhost:8025/g" .env
endif
endif

# Generate the TLS CA certificate to create and sign server certificates for Traefik
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

# Generate the TLS server certificates for Traefik to use
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
# Destinations
# ---------------------------

# Create the secrets directory
.PHONY: secrets-dir
secrets-dir:
	$(call log_notice, "Creating directory for secrets at: $(SECRETS_DIR)")
	@mkdir -p $(SECRETS_DIR)
	@mkdir -p $(SECRETS_TLS_DIR)

# Create the distribution directory
.PHONY: output-dir
output-dir:
	$(call log_notice, "Creating directory for distributables at: $(OUTPUT_DIR)")
	@mkdir -p $(OUTPUT_DIR)

# ---------------------------
# Housekeeping
# ---------------------------

.PHONY: prune-env
prune-env:
	$(call log_success, "Removing assets created by Docker Compose!")
	@$(docker) compose -f compose.yaml down -v

.PHONY: prune-bootstrap
prune-bootstrap:
	$(call log_success, "Removing local bootstrapping files!")
	@$(SCRIPT_DIR)/hosts.sh remove

.PHONY: prune-compose-network
prune-compose-network:
	$(call log_success, "Removing public Docker Compose network!")
	@$(docker) network rm public --force

.PHONY: prune-secrets
prune-secrets:
	$(call log_success, "Removing local secrets in $(SECRETS_DIR)!")
	rm -rf $(SECRETS_DIR)

.PHONY: prune-output
prune-output:
	$(call log_success, "Removing local distributables in $(OUTPUT_DIR)!")
	rm -rf $(OUTPUT_DIR)

.PHONY: prune-deps
prune-deps:
	$(call log_success, "Removing local dependencies in $(DEPENDENCY_DIR)!")
	rm -rf $(DEPENDENCY_DIR)

# ---------------------------
# Checks
# ---------------------------
.PHONY: version
version:
	@echo -n "$(VERSION)"

.PHONY: name
name:
	@echo -n "$(NAME)"

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