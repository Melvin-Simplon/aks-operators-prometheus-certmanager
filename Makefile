SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

TF_DIR   ?= terraform
LOG_FILE ?= .logs/terraform.log

# Exported, never passed as positional args: scripts read the environment
export TF_DIR LOG_FILE

include makefiles/terraform.mk
include makefiles/common.mk
