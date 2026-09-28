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
include makefiles/helm.mk
include makefiles/k8s.mk
include makefiles/common.mk
