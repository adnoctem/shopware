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

# Only export variables from here since we do not want to mix the top-level
# Makefile's notion of 'SOURCES' with the different sub-makes
export

# ---------------------------
# Constants
# ---------------------------
CONFIG_DIR := $(ROOT_DIR)/config
CONFIG_TLS_DIR := $(CONFIG_DIR)/ssl
OUTPUT_DIR := $(ROOT_DIR)/dist
DOCKER_DIR := $(ROOT_DIR)/docker
SECRETS_DIR := $(ROOT_DIR)/secrets
SECRETS_TLS_DIR := $(SECRETS_DIR)/ssl
VENDOR_DIR := $(ROOT_DIR)/vendor
VAR_DIR := $(ROOT_DIR)/var
PUBLIC_DIR := $(ROOT_DIR)/public
CI_DIR := $(ROOT_DIR)/.github
CI_LINTER_DIR := $(CI_DIR)/linters

# Configuration files
MARKDOWNLINT_CONFIG := $(CI_LINTER_DIR)/.markdown-lint.yml
GITLEAKS_CONFIG := $(CI_LINTER_DIR)/.gitleaks.toml
BAKE_CONFIG := $(DOCKER_DIR)/docker-bake.hcl

FIND_FLAGS := -maxdepth 1 -mindepth 1 -type d -exec \basename {} \;
TAR_EXCLUDE_FLAGS := --exclude='./docker' --exclude='./secrets' --exclude='./.github' --exclude='./dist' --exclude-from'=./.gitignore'

# general variables
#DATE := $(shell date '+%d.%m.%y-%T')
GIT_VERSION := $(shell git describe --tags $(git rev-list --tags --max-count=1) 2>/dev/null)
VERSION := $(strip $(if $(filter-out "fatal: No names found.*", $(GIT_VERSION)), $(shell echo $(GIT_VERSION)), $(shell echo 0.1.0)))
NAME := $(shell jq -r '.name' $(ROOT_DIR)/composer.json)

# executables
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
ENV ?= dev
TAG ?= $(VERSION)
TARGET ?= default
APP ?= shopware
CI ?= n

# Docker image
PHP_VERSION ?= 8.3
PORT ?= 9161
BAKE_ARGS ?=

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

define DEV_KUSTOMIZATION
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
secretGenerator:
  - name: root-ca
    type: "kubernetes.io/tls"
    namespace: cert-manager
    files:
      - tls.crt=ca.pem
      - tls.key=ca-key.pem
    options:
      disableNameSuffixHash: true
      annotations:
        reflector.v1.k8s.emberstack.com/reflection-allowed: "false"
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
init: deps dotenv
#ifeq ($(CI), y)
#	$(call log_notice, "Installing Composer dependencies")
#	@$(MAKE) deps
#	$(call log_notice, "Generating new custom .env.local file from .env")
#	@$(MAKE) dotenv ENV=test
#else
#	$(call log_notice, "Installing Composer dependencies")
#	@$(MAKE) deps
#	$(call log_notice, "Generating TLS certificates")
#	@$(MAKE) secrets
#	$(call log_notice, "Creating Docker Compose networks")
#	@$(MAKE) compose-network
#	$(call log_notice, "Bootstrapping /etc/hosts for custom hostnames")
#	@$(MAKE) bootstrap
#	$(call log_notice, "Generating new custom .env.local file from .env")
#	@$(MAKE) dotenv
#endif
endif

define ENV_INFO
# Manage the execution environment for Shopware 6. This creates a local Docker Compose
# project which bootstraps a local MySQL 8 database and ElasticSearch 2 Node, which
# Shopware requires for Docker image builds, etc.
#
# See the target's prerequisites for information about the commands executed.
#
# Arguments:
#   PRINT_HELP: 'y' or 'n'
endef
#.PHONY: env
#ifeq ($(PRINT_HELP), y)
#env:
#	echo "$$ENV_INFO"
#else
#env:
#	@$(MAKE) compose CI=y
#endif

define DEV_INFO
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
#.PHONY: dev
#ifeq ($(PRINT_HELP), y)
#dev:
#	echo "$$DEV_INFO"
#else
#dev:
#	@$(MAKE) compose
#endif

define DEV_CLEANUP_INFO
# Clean up the development environment for Shopware 6.
#
# Arguments:
#   PRINT_HELP: 'y' or 'n'
endef
#.PHONY: clean
#ifeq ($(PRINT_HELP), y)
#clean:
#	echo "$$DEV_CLEANUP_INFO"
#else
#clean:
#	@$(MAKE) prune-compose CI=$(CI)
#endif

define TESTS_INFO
# Run tests for Shopware using PHPUnit. This does basic validation that the application
# still boots and runs with our current configuration.
endef
#.PHONY: tests
#ifeq ($(PRINT_HELP), y)
#tests:
#	echo "$$TESTS_INFO"
#else
#tests:
#	@$(MAKE) dotenv ENV=test
#	@composer run tests
#endif

define PRUNE_INFO
# Remove the local configuration

# Create a local development environment for Helm charts. This is a wrapper
# target which requires the 'dev-cluster' and 'dev-cluster-bootstrap' Make
# targets.
endef
#.PHONY: prune
#ifeq ($(PRINT_HELP), y)
#prune:
#	echo "$$PRUNE_INFO"
#else
#prune:
#	@$(MAKE) prune-bootstrap
#	@$(MAKE) prune-compose
#	@$(MAKE) prune-compose CI=y
#	@$(MAKE) prune-compose-network
#	@$(MAKE) prune-files
#endif

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
	-$(docker) buildx build -t $(NAME):$(TAG) -t $(NAME):latest \
		--network host \
 		--target $(ENV) \
	 	--build-arg PHP_VERSION=$(PHP_VERSION) .
endif

define BAKE_INFO
# Bake Docker images.
endef
.PHONY: bake
.ONESHELL:
ifeq ($(PRINT_HELP), y)
bake:
	echo "$$BAKE_INFO"
else
bake:
	$(call log_notice, "Baking Docker images for target: $(TARGET)!")
	export $(shell grep -v '^#' .env | xargs)
	export VERSION=$(TAG)
	@$(docker) buildx bake --file $(BAKE_CONFIG) $(TARGET) --builder default $(BAKE_ARGS)
endif

define BUNDLE_INFO
# Build a Tarball bundle of the project's sources.
endef
.PHONY: bundle
ifeq ($(PRINT_HELP), y)
bundle:
	echo "$$BUNDLE_INFO"
else
bundle: prune-output output-dir
	$(call log_notice, "Building a Tarball bundle of $(APP)!")
	@tar $(TAR_EXCLUDE_FLAGS) -cvzf $(OUTPUT_DIR)/bundle.tar.gz .
	@cd $(OUTPUT_DIR) && sha256sum bundle.tar.gz >> CHECKSUMS_SHA256.txt
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
#.PHONY: secrets
#ifeq ($(PRINT_HELP), y)
#secrets:
#	echo "$$SECRETS_INFO"
#else
#secrets: secrets-dir secrets-gen-ca secrets-gen-server
#ifeq ($(shell test -e /tmp/sw-backup.sql && echo -n yes ), yes)
#	$(call log_attention, "Found Shopware backup.sql in /tmp! Importing into secrets...")
#	@mv /tmp/sw-backup.sql $(SECRETS_DIR)/backup.sql
#endif
#endif

# ---------------------------
#   Dependencies
# ---------------------------
# setup
#.PHONY: bootstrap
#bootstrap:
#	$(call log_notice, "Bootstrapping host machine DNS entries!")
#	@$(SCRIPT_DIR)/hosts.sh add

.PHONY: start
start:
	$(call log_notice, "Starting Shopware on local Symfony development server!")
	@$(docker) compose --file docker/compose-base.yaml up -d
	@$(composer) run deployment-helper
	@symfony server:start -d --no-tls --allow-http
	@symfony server:log

.PHONY: stop
stop:
	$(call log_notice, "Stopping Shopware on local Symfony development server!")
	@symfony server:stop
	@$(docker) compose --file docker/compose-base.yaml down -v

#.PHONY: compose
#compose:
#	$(call log_notice, "Starting Docker Compose project")
#	@$(docker) compose up -d

#.PHONY: compose-network
#compose-network:
#	$(call log_notice, "Creating Docker Compose networks")
#	@$(docker) network rm public --force
#	@$(docker) network create \
#		--subnet $(COMPOSE_SUBNET) \
#		--gateway $(COMPOSE_GATEWAY_IP) \
#		public

# ignore extensions for dependency installations
.PHONY: deps
deps:
	$(call log_notice, "Installing project Composer dependencies")
	@composer install --no-interaction \
		--ignore-platform-req=ext-opentelemetry \
		--ignore-platform-req=ext-grpc \
		--ignore-platform-req=php

#.PHONY: pre-commit
#pre-commit:
#	$(call log_notice, "Installing project Pre-Commit dependencies")
#	@pre-commit install

#.PHONY: logs
#logs:
#	$(call log_notice, "Streaming Docker container logs for $(APP)")
#	@$(docker) logs -f $(shell docker ps -aq -f 'label=application=$(APP)')

# ---------------------------
# Dumps & Backups
# ---------------------------

.PHONY: dumps
dumps:
	$(call log_notice, "Dumping Shopware\'s static build information")
	php bin/console theme:dump
	php bin/console feature:dump
	php bin/console bundle:dump

.PHONY: mysql-backup
mysql-backup:
	$(call log_notice, "Creating a backup of Shopware\'s MySQL database")
	@docker exec mysql /usr/bin/mysqldump -u root --password=shopware shopware > $(SECRETS_DIR)/backup.sql

.PHONY: mysql-import
mysql-import:
	$(call log_notice, "Creating a backup of Shopware\'s MySQL database")
	cat $(SECRETS_DIR)/backup.sql | docker exec -i mysql /usr/bin/mysql -u root --password=shopware shopware

# ---------------------------
# Credentials & Secrets
# ---------------------------

.PHONY: secrets
secrets: secrets-dir secrets-gen-ca secrets-gen-server
	$(call log_notice, "Creating development Kustomization!")
	$(file > $(SECRETS_TLS_DIR)/kustomization.yaml,$(DEV_KUSTOMIZATION))

# Generate the Symfony projects local '.env' file to configure the project
.PHONY: dotenv
dotenv:
ifeq ($(shell test -e .env && echo -n yes), yes)
	$(call log_attention, "Skipping generation of .env: file exists!")
else
	$(call log_notice, "Generating .env for Shopware configuration from template")
	@cp .env.template .env
	@sed -i -e "s/APP_SECRET=CHANGEME/APP_SECRET=$(shell head -c 512 /dev/urandom | LC_CTYPE=C tr -cd 'a-zA-Z0-9' | head -c 80)/g" .env
	@sed -i -e "s/INSTANCE_ID=CHANGEME/INSTANCE_ID=$(shell head -c 512 /dev/urandom | LC_CTYPE=C tr -cd 'a-zA-Z0-9' | head -c 32)/g" .env
	@sed -i -e "s/DATABASE_URL=mysql:\/\/shopware:shopware@127.0.0.1:3306\/shopware/DATABASE_URL=mysql:\/\/shopware:shopware@mysql:3306\/shopware/g" .env
	@sed -i -e "s/APP_URL=http:\/\/localhost:8000/APP_URL=https:\/\/shopware.internal/g" .env
	@sed -i -e "s/MAILER_DSN=smtp:\/\/shopware:shopware@127.0.0.1:1025/MAILER_DSN=smtp:\/\/shopware:shopware@mailpit:1025/g" .env
	@sed -i -e "s/STOREFRONT_PROXY_URL=http:\/\/localhost:8000/STOREFRONT_PROXY_URL=https:\/\/shopware.internal/g" .env
	@sed -i -e "s/OPENSEARCH_URL=http:\/\/127.0.0.1:9200/OPENSEARCH_URL=http:\/\/opensearch:9200/g" .env
	@sed -i -e "s/OTEL_PHP_AUTOLOAD_ENABLED=false/OTEL_PHP_AUTOLOAD_ENABLED=true/g" .env
	@sed -i -e "s/OTEL_EXPORTER_OTLP_ENDPOINT=http:\/\/127.0.0.1:4317/OTEL_EXPORTER_OTLP_ENDPOINT=http:\/\/otel-collector:4317/g" .env
	@sed -i -e "s/SHOPWARE_S3_ACCESS_KEY=CHANGEME/SHOPWARE_S3_ACCESS_KEY=$(shell head -c 512 /dev/urandom | LC_CTYPE=C tr -cd 'a-zA-Z0-9' | head -c 32)/g" .env
	@sed -i -e "s/SHOPWARE_S3_SECRET_KEY=CHANGEME/SHOPWARE_S3_SECRET_KEY=$(shell head -c 512 /dev/urandom | LC_CTYPE=C tr -cd 'a-zA-Z0-9' | head -c 64)/g" .env
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

.PHONY: dirs
dirs: secrets-dir output-dir

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

#.PHONY: prune-bootstrap
#prune-bootstrap:
#	$(call log_attention, "Removing hostnames from /etc/hosts!")
#	@$(SCRIPT_DIR)/hosts.sh remove
#
#.PHONY: prune-compose
#prune-compose:
#	$(call log_attention, "Stopping Docker Compose project!")
#ifeq ($(CI), y)
#	@$(docker) compose --env-file $(ENV_FILE) -f docker/cluster/compose-base.yaml down -v
#else
#	@$(docker) compose --env-file $(ENV_FILE) -f docker/cluster/compose.yaml down -v
#endif
#
#.PHONY: prune-compose-network
#prune-compose-network:
#	$(call log_attention, "Removing public Docker Compose network!")
#	@$(docker) network rm public --force

.PHONY: prune-files
prune-files: prune-secrets prune-output prune-deps prune-var prune-public prune-install prune-theme

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
	$(call log_attention, "Removing Shopware dependencies in $(VENDOR_DIR)!")
	rm -rf $(VENDOR_DIR)

.PHONY: prune-var
prune-var:
	$(call log_attention, "Cleaning up Shopware var directory in $(VAR_DIR)!")
	rm -rf $(VAR_DIR)/cache
	rm -rf $(VAR_DIR)/log
	rm -rf $(VAR_DIR)/*.json
	rm -rf $(VAR_DIR)/*.scss

.PHONY: prune-public
prune-public:
	$(call log_attention, "Cleaning up Shopware public directory in $(PUBLIC_DIR)!")
	rm -rf $(PUBLIC_DIR)/bundles
	rm -rf $(PUBLIC_DIR)/media
	rm -rf $(PUBLIC_DIR)/theme
	rm -rf $(PUBLIC_DIR)/thumbnail
	rm -rf $(PUBLIC_DIR)/sitemap

.PHONY: prune-install
prune-install:
	$(call log_attention, "Removing Shopware\'s install.lock!")
	rm -rf $(ROOT_DIR)/install.lock

.PHONY: prune-theme
prune-theme:
	$(call log_attention, "Removing Shopware theme configuration!")
	rm -rf $(ROOT_DIR)/files/theme-config

# ---------------------------
# Checks
# ---------------------------
#.PHONY: version
#version:
#	@echo -n "$(VERSION)"
#
.PHONY: name
name:
	@echo -n "$(NAME)@$(VERSION)"

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
	@shfmt -d $(shell shfmt -f . | grep -E "^bin/|^docker/|^scripts/")
