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

# Build output
OUT_DIR := $(ROOT_DIR)/dist
SCRIPT_DIR := $(ROOT_DIR)/scripts
CONFIG_DIR := $(ROOT_DIR)/config
CONFIG_K8S_DIR := $(CONFIG_DIR)/k8s
DOCKER_DIR := $(ROOT_DIR)/docker
SECRETS_DIR := $(ROOT_DIR)/secrets
CI_DIR := $(ROOT_DIR)/.github

# Documentation
DOCS_DIR := $(ROOT_DIR)/docs
MARKDOWNLINT_CONFIG := $(CI_DIR)/linters/.markdown-lint.yml

DATE := $(shell date '+%d.%m.%y-%T')

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
CHART ?=
VALUES ?=

REGISTRY ?= ghcr.io
REGISTRY_USER ?=


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
env: compose
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

.PHONY: compose
compose:
	$(call log_success, "Starting Docker Compose")
	@docker compose up -f $(DOCKER_DIR)/compose.yaml -d

.PHONY: registry-login
registry-login:
ifndef REGISTRY_USER
	$(call log_attention, "Cannot login to $(REGISTRY) registry using empty username! REGISTRY_USER must be defined")
else
	gh auth token | docker login $(REGISTRY) -u $(REGISTRY_USER) --password-stdin
endif

# ---------------------------
# Linting
# ---------------------------
.PHONY: lint
lint: markdownlint actionlint shellcheck shfmt gitleaks

.PHONY: markdownlint
markdownlint:
	markdownlint -c $(MARKDOWNLINT_CONFIG) '**/*.md' --ignore 'vendor'

.PHONY: actionlint
actionlint:
	actionlint

.PHONY: gitleaks
gitleaks:
	gitleaks detect --no-banner --no-git --redact --config $(GITLEAKS_CONFIG) --verbose --source .

.PHONY: shellcheck
shellcheck:
	shellcheck scripts/**/*.sh -x

.PHONY: shfmt
shfmt:
	shfmt -d .