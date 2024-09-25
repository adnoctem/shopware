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
VAR_DIR := $(ROOT_DIR)/var
PUBLIC_DIR := $(ROOT_DIR)/public
DOCKER_DIR := $(ROOT_DIR)/docker
CI_DIR := $(ROOT_DIR)/.github
CI_LINTER_DIR := $(CI_DIR)/linters
PLUGIN_DIR := $(ROOT_DIR)/custom/plugins
APPS_DIR := $(ROOT_DIR)/custom/apps

# Configuration files
MARKDOWNLINT_CONFIG := $(CI_LINTER_DIR)/.markdown-lint.yml
GITLEAKS_CONFIG := $(CI_LINTER_DIR)/.gitleaks.toml
DOCKERFILE := $(ROOT_DIR)/Dockerfile

FIND_FLAGS := -maxdepth 1 -mindepth 1 -type d -exec \basename {} \;
TAR_EXCLUDE_FLAGS := --exclude='./docker' --exclude='./scripts' --exclude='./.github'
PHP_EXTENSIONS := +default +gd +intl +iconv +sodium +pdo +mysql
PLUGINS := $(shell find $(PLUGIN_DIR) $(FIND_FLAGS))
APPS := $(shell find $(APPS_DIR) $(FIND_FLAGS))

COMPOSE_SUBNET := 172.25.0.0/16
COMPOSE_GATEWAY_IP := 172.25.0.1

# general variables
DATE := $(shell date '+%d.%m.%y-%T')
GIT_VERSION := $(shell git describe --tags $(git rev-list --tags --max-count=1) 2>/dev/null)
VERSION := $(strip $(if $(filter-out "fatal: No names found.*", $(GIT_VERSION)), $(shell echo $(GIT_VERSION)), $(shell echo v0.1.0)))
NAME := $(shell composer show --self | grep 'names' | grep -o -E '\w+/\w+' | cut -d' ' -f 2)

# Executables
docker := docker
php := php # at least version 8.2
composer := composer
kind := kind # to be used later
node := node
cfssl := cfssl
pre-commit := pre-commit

EXECUTABLES := $(docker) $(php) $(composer) $(kind) $(node) $(cfssl) $(pre-commit)

# ---------------------------
# User-defined variables
# ---------------------------
PRINT_HELP ?=
TAG ?= $(VERSION)
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
# See the target's prerequisites for information about the commands executed.
endef
.PHONY: init
ifeq ($(PRINT_HELP), y)
init:
	echo "$$INIT_INFO"
else
init: dotenv buildenv deps secrets compose-network
endif

define CI_INFO
# Initialize the project in CI mode.
#
# See the target's prerequisites for information about the commands executed.
endef
.PHONY: ci
ifeq ($(PRINT_HELP), y)
ci:
	echo "$$CI_INFO"
else
ci: dotenv deps
endif

define ENV_INFO
# Manage the development environment for Shopware 6. This creates a local Docker Compose
# project using Traefik, which provides HTTPS access to all (public) services within the
# project. Finally the target will follow the Docker logs for the "shopware" container.
# If the "DESTROY" variable is set it will remove the environment.
#
# See the target's prerequisites for information about the commands executed.
#
# Arguments:
#   PRINT_HELP: 'y' or 'n'
endef
.PHONY: env
ifeq ($(PRINT_HELP), y)
env:
	echo "$$ENV_INFO"
else
env: bootstrap compose
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
env-cleanup: prune-compose prune-compose-network prune-bootstrap
endif

define TESTS_INFO
# Run each plugin or app's custom test suite via sub-makes.
endef
#.PHONY: tests
#ifeq ($(PRINT_HELP), y)
#tests:
#	echo "$$TESTS_INFO"
#else
#tests:
#endif

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
prune: prune-output prune-secrets prune-deps prune-var prune-public prune-install prune-bootstrap prune-compose prune-compose-network prune-buildenv
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
	$(call log_notice, "Building Docker image $(NAME):$(TAG)!")
	-$(docker) buildx build -f $(DOCKERFILE) -t $(NAME):$(TAG) -t $(NAME):latest .
endif

define BUNDLE_INFO
# Build a Tarball bundle of the project's sources.
endef
.PHONY: bundle
ifeq ($(PRINT_HELP), y)
bundle:
	echo "$$BUNDLE_INFO"
else
bundle: output-dir
	$(call log_notice, "Building a Tarball bundle of $(APP)!")
	@tar -cvzf $(TAR_EXCLUDE_FLAGS) $(OUTPUT_DIR)/$(NAME)_$(VERSION).tar.gz .
	@cd $(OUTPUT_DIR) && sha256sum >> CHECKSUMS_SHA256.txt
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
	$(call log_notice, "Bootstrapping host machine DNS entries!")
	@$(SCRIPT_DIR)/hosts.sh add

.PHONY: buildenv
buildenv:
	$(call log_notice, "Starting Shopware build environment!")
	@$(docker) compose -f docker/compose.yaml up -d

.PHONY: symfony-start
symfony-start: buildenv
	$(call log_notice, "Starting Shopware on local Symfony development server!")
	@symfony server:start -d --no-tls
	@symfony server:log

.PHONY: symfony-stop
symfony-stop:
	$(call log_notice, "Stopping Shopware on local Symfony development server!")
	@symfony server:stop
	$(MAKE) prune-buildenv

.PHONY: compose
compose:
	$(call log_notice, "Starting Docker Compose project")
	@$(docker) compose -f docker/compose-override.yaml up -d
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
deps:
	$(call log_notice, "Installing project Composer dependencies")
	@composer install --no-interaction

.PHONY: pre-commit
pre-commit:
	$(call log_notice, "Installing project Pre-Commit dependencies")
	@pre-commit install

.PHONY: logs
logs:
	$(call log_notice, "Streaming Docker container logs for $(APP)")
	@$(docker) logs -f $(shell docker ps -aq -f 'label=application=$(APP)')

# ---------------------------
# Credentials & Secrets
# ---------------------------

# Generate the Symfony projects local '.env' file to configure the project
.PHONY: dotenv
dotenv:
ifeq ($(shell test -e .env.local && echo -n yes), yes)
	$(call log_attention, "Skipping generation of .env.local for Shopware. File exists!")
else
	$(call log_notice, "Generating .env for Shopware configuration from template")
	@cp .env .env.local
	@sed -i -e "s/APP_SECRET=CHANGEME/APP_SECRET=$(shell head -c 512 /dev/urandom | LC_CTYPE=C tr -cd 'a-zA-Z0-9' | head -c 80)/g" .env.local
	@sed -i -e "s/INSTANCE_ID=CHANGEME/INSTANCE_ID=$(shell head -c 512 /dev/urandom | LC_CTYPE=C tr -cd 'a-zA-Z0-9' | head -c 32)/g" .env.local
ifeq ($(CI), y)
	$(call log_notice, "Updating .env for Shopware CI")
	@sed -i -e "s/DATABASE_URL=mysql://shopware:shopware@mysql:3306/shopware/DATABASE_URL=mysql://shopware:shopware@loca:3306/shopware/g" .env.local
	@sed -i -e "s/OPENSEARCH_URL=http://opensearch:9200/OPENSEARCH_URL=http://localhost:9200/g" .env.local
	@sed -i -e "s/MAILER_DSN=smtp://shopware:shopware@mailpit:1025/MAILER_DSN=smtp://shopware:shopware@localhost:8025/g" .env.local
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

.PHONY: prune-bootstrap
prune-bootstrap:
	$(call log_attention, "Removing hostnames from /etc/hosts!")
	@$(SCRIPT_DIR)/hosts.sh remove

.PHONY: prune-compose
prune-compose:
	$(call log_attention, "Stopping Docker Compose project!")
	@$(docker) compose -f docker/compose-override.yaml down -v

.PHONY: prune-compose-network
prune-compose-network:
	$(call log_attention, "Removing public Docker Compose network!")
	@$(docker) network rm public --force

.PHONY: prune-buildenv
prune-buildenv:
	$(call log_attention, "Removing Shopware build environment!")
	@$(docker) compose -f docker/compose.yaml down -v

.PHONY: prune-secrets
prune-secrets:
	$(call log_attention, "Removing secrets in $(SECRETS_DIR)!")
	rm -rf $(SECRETS_DIR)

.PHONY: prune-output
prune-output:
	$(call log_attention, "Removing distributables in $(OUTPUT_DIR)!")
	rm -rf $(OUTPUT_DIR)

.PHONY: prune-deps
prune-deps:
	$(call log_attention, "Removing Shopware dependencies in $(DEPENDENCY_DIR)!")
	rm -rf $(DEPENDENCY_DIR)

.PHONY: prune-var
prune-var:
	$(call log_attention, "Cleaning up Shopware var directory in $(VAR_DIR)!")
	rm -rf $(VAR_DIR)/cache/*
	rm -rf $(VAR_DIR)/log/*

.PHONY: prune-public
prune-public:
	$(call log_attention, "Cleaning up Shopware public directory in $(PUBLIC_DIR)!")
	rm -rf $(PUBLIC_DIR)/bundles/*
	rm -rf $(PUBLIC_DIR)/media/*
	rm -rf $(PUBLIC_DIR)/theme/*
	rm -rf $(PUBLIC_DIR)/thumbnail/*
	rm -rf $(PUBLIC_DIR)/sitemap/*

.PHONY: prune-install
prune-install:
	$(call log_attention, "Removing Shopware\'s install.lock!")
	rm -rf $(ROOT_DIR)/install.lock

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
	$(call log_notice, "Running 'tools-check' for $(APP)")
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
