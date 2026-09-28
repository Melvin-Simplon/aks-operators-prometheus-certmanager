#!/usr/bin/env bash
# Apply the manifests of k8s/<component>/ (plain files, or kustomize when the directory holds a
# kustomization.yaml), in the given order, then wait for the
# resources that report a Ready condition (issuers, certificates).
# Usage: k8s-apply.sh <component> [<component>...]
# Env: KUBE_CONTEXT, LOG_DIR, READY_TIMEOUT
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
HOST_LABEL="kubectl"
LOG_FILE="${LOG_DIR:-.logs}/kubectl.log"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"
# shellcheck source=scripts/kube.sh
source "${SCRIPT_DIR}/kube.sh"

: "${READY_TIMEOUT:=120s}"
readonly READY_TIMEOUT
readonly READY_KINDS=" Certificate ClusterIssuer Issuer "

usage() {
    printf 'Usage: %s <component> [<component>...]\n' "$(basename "$0")" >&2
    exit 2
}

component_dir() {
    printf '%s/k8s/%s' "${ROOT_DIR}" "$1"
}

# Prints "-k" for a kustomize directory (kustomization.yaml), "-f" for plain manifests
source_flag() {
    if [[ -f "$(component_dir "$1")/kustomization.yaml" ]]; then
        printf '%s' "-k"
    else
        printf '%s' "-f"
    fi
}

check_components() {
    local component
    for component in "$@"; do
        [[ -d "$(component_dir "${component}")" ]] || fatal "k8s/${component}/ not found"
    done
}

# One issue per applied object, from lines like "certificate.cert-manager.io/grafana created"
apply_component() {
    local component="$1" dir out line object action
    dir="$(component_dir "${component}")"
    task "kubectl : apply k8s/${component}"
    if ! out="$(kctl apply "$(source_flag "${component}")" "${dir}" 2>&1)"; then
        log_file "${out}"
        printf '%s\n' "${out}" >&2
        fatal "kubectl apply failed for k8s/${component}"
    fi
    while IFS= read -r line; do
        [[ -z "${line}" ]] && continue
        object="${line% *}"
        action="${line##* }"
        case "${action}" in
            created)    issue change created "${object}"; count created ;;
            configured) issue change configured "${object}"; count configured ;;
            unchanged)  issue desired unchanged "${object}"; count unchanged ;;
            *)          detail "${line}" ;;
        esac
    done <<< "${out}"
}

# Waits for every object of the component whose kind is in READY_KINDS
wait_component_ready() {
    local component="$1" kind namespace name ns_args line
    while read -r kind namespace name; do
        [[ "${READY_KINDS}" == *" ${kind} "* ]] || continue
        task "kubectl : ${kind} ${name} is ready"
        ns_args=()
        [[ "${namespace}" != "<none>" ]] && ns_args=(-n "${namespace}")
        if kctl wait --for=condition=Ready "${kind}/${name}" "${ns_args[@]}" --timeout="${READY_TIMEOUT}" > /dev/null 2>&1; then
            issue desired ready "${kind,,}/${name}"
            count ready
        else
            while IFS= read -r line; do
                detail "${line}"
            done < <(kctl describe "${kind}/${name}" "${ns_args[@]}" 2>&1 | sed -n '/^Status:/,$p' | head -20)
            fatal "${kind}/${name} not ready after ${READY_TIMEOUT}"
        fi
    done < <(kctl get "$(source_flag "${component}")" "$(component_dir "${component}")" \
        -o custom-columns=KIND:.kind,NS:.metadata.namespace,NAME:.metadata.name --no-headers)
}

main() {
    (( $# >= 1 )) || usage
    init_log "k8s-apply.sh $*"
    RECAP_KEYS=(checked created configured unchanged ready unreachable failed)

    require_cmd kubectl
    check_components "$@"
    check_cluster

    local component
    for component in "$@"; do
        apply_component "${component}"
        wait_component_ready "${component}"
    done
    finish
}

main "$@"
