SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

TF_DIR       ?= terraform
KUBE_CONTEXT ?= test-steve
LOG_DIR      ?= .logs

# Exported, never passed as positional args: scripts read the environment
export TF_DIR KUBE_CONTEXT LOG_DIR

include makefiles/terraform.mk
include makefiles/helm.mk
include makefiles/common.mk
