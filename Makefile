SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := menu

TF_DIR       ?= terraform
KUBE_CONTEXT ?= test-steve
DOMAIN       ?= monitoring-groupe3.polandcentral.cloudapp.azure.com
LOG_DIR      ?= .logs

# Exported, never passed as positional args: scripts read the environment
export TF_DIR KUBE_CONTEXT DOMAIN LOG_DIR

include makefiles/terraform.mk
include makefiles/deploy.mk
include makefiles/access.mk
include makefiles/common.mk
