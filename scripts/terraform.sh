#!/usr/bin/env bash
# Terraform workflow: init, fmt, validate, plan, confirm, apply.
# Usage: terraform.sh check|plan|apply
# Env: TF_DIR, LOG_DIR, AUTO_APPROVE=1 to skip the confirmation (CI)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_LABEL="terraform"
LOG_FILE="${LOG_DIR:-.logs}/terraform.log"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

: "${TF_DIR:=terraform}"
readonly TF_DIR
readonly PLAN_FILE="tfplan.bin"
readonly EXIT_REFUSED=3

usage() {
    printf 'Usage: %s check|plan|apply\n' "$(basename "$0")" >&2
    exit 2
}

# Run terraform in TF_DIR, print its output only if it fails
tf_quiet() {
    local out
    if out="$(terraform -chdir="${TF_DIR}" "$@" -no-color 2>&1)"; then
        log_file "${out}"
    else
        log_file "${out}"
        printf '%s\n' "${out}" >&2
        return 1
    fi
}

check_azure_session() {
    task "azure : session is active"
    if az account get-access-token --output none 2> /dev/null; then
        issue desired "logged in" "$(az account show --query name --output tsv)"
        count checked
    else
        unreachable "no valid Azure session, run 'az login'"
    fi
}

ensure_init() {
    task "terraform : init"
    local first_run=false
    [[ -d "${TF_DIR}/.terraform" ]] || first_run=true
    tf_quiet init -input=false || fatal "terraform init failed"
    if [[ "${first_run}" == "true" ]]; then
        issue change installed "providers downloaded"
    else
        issue desired ready "providers and backend already initialized"
    fi
    count checked
}

ensure_fmt() {
    task "terraform : fmt"
    local files
    files="$(terraform -chdir="${TF_DIR}" fmt -recursive)" || fatal "terraform fmt failed"
    if [[ -n "${files}" ]]; then
        issue change formatted "${files//$'\n'/, }"
    else
        issue desired formatted "nothing to reformat"
    fi
    count checked
}

ensure_valid() {
    task "terraform : validate"
    tf_quiet validate || fatal "configuration is invalid"
    issue desired valid "configuration is valid"
    count checked
}

# Reads "Plan: 1 to import, 2 to add, 0 to change, 1 to destroy." into the recap counters
# and the global PLAN_SUMMARY, so it must not be called in $(...)
count_plan_actions() {
    local summary action n
    summary="$(terraform -chdir="${TF_DIR}" show -no-color "${PLAN_FILE}" | grep '^Plan:' || true)"
    for action in import add change destroy; do
        n=0
        if [[ "${summary}" =~ ([0-9]+)\ to\ ${action} ]]; then
            n="${BASH_REMATCH[1]}"
        fi
        count "${action}" "${n}"
    done
    summary="${summary#Plan: }"
    PLAN_SUMMARY="${summary%.}"
}

# Sets the global HAS_CHANGES, so it must not be called in $(...)
make_plan() {
    task "terraform : plan"
    local rc=0
    run_logged terraform -chdir="${TF_DIR}" plan -input=false -detailed-exitcode -out="${PLAN_FILE}" || rc=$?
    case "${rc}" in
        0)
            HAS_CHANGES=false
            issue desired "up to date" "infrastructure matches the configuration"
            ;;
        2)
            HAS_CHANGES=true
            count_plan_actions
            issue change pending "${PLAN_SUMMARY:-see plan above}"
            ;;
        *)
            fatal "terraform plan failed"
            ;;
    esac
}

confirm_apply() {
    [[ "${AUTO_APPROVE:-0}" == "1" ]] && return 0
    local answer=""
    printf '\n'
    read -r -p "Apply this plan? [y/N] " answer < /dev/tty || true
    # Some terminals (WSL, raw mode) append a carriage return or spaces
    answer="${answer//[[:space:]]/}"
    case "${answer,,}" in
        y | yes) return 0 ;;
    esac
    log_file "confirmation input: $(printf '%q' "${answer}")"
    task "terraform : apply"
    fatal "apply cancelled by user" "${EXIT_REFUSED}"
}

apply_plan() {
    if [[ "${HAS_CHANGES}" != "true" ]]; then
        task "terraform : apply"
        issue skip skipping "nothing to apply"
        count skipped
        return 0
    fi
    confirm_apply
    task "terraform : apply"
    run_logged terraform -chdir="${TF_DIR}" apply -input=false "${PLAN_FILE}" || fatal "terraform apply failed"
    issue change applied "plan applied"
    count applied
}

# shellcheck disable=SC2317 # called by the EXIT trap
cleanup_plan() {
    rm -f "${TF_DIR}/${PLAN_FILE}"
}

run_check() {
    ensure_init
    ensure_fmt
    ensure_valid
}

run_plan() {
    check_azure_session
    run_check
    make_plan
}

run_apply() {
    run_plan
    apply_plan
}

main() {
    (( $# == 1 )) || usage
    init_log "terraform.sh $1"
    trap cleanup_plan EXIT

    # Only counters that can move in this mode are shown
    case "$1" in
        check) RECAP_KEYS=(checked failed) ;;
        plan)  RECAP_KEYS=(checked import add change destroy unreachable failed) ;;
        apply) RECAP_KEYS=(checked import add change destroy applied skipped unreachable failed) ;;
        *)     usage ;;
    esac

    require_cmd terraform
    [[ "$1" == "check" ]] || require_cmd az

    HAS_CHANGES=false
    PLAN_SUMMARY=""
    case "$1" in
        check) run_check ;;
        plan)  run_plan ;;
        apply) run_apply ;;
    esac
    finish
}

main "$@"
