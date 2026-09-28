#!/usr/bin/env bash
# Install or upgrade one Helm release defined in helm/<release>/ (release.env + values.yaml).
# Idempotent: the config checksum is stored in the release description, an unchanged
# config is not upgraded again.
# Usage: helm-release.sh <release>
# Env: KUBE_CONTEXT, LOG_DIR, HELM_TIMEOUT
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
HOST_LABEL="helm"
LOG_FILE="${LOG_DIR:-.logs}/helm.log"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

: "${KUBE_CONTEXT:?KUBE_CONTEXT must be set}"
: "${HELM_TIMEOUT:=5m}"
readonly KUBE_CONTEXT HELM_TIMEOUT

usage() {
    printf 'Usage: %s <release>\n' "$(basename "$0")" >&2
    exit 2
}

load_release() {
    local release_dir="${ROOT_DIR}/helm/${RELEASE}"
    RELEASE_ENV="${release_dir}/release.env"
    VALUES_FILE="${release_dir}/values.yaml"
    [[ -f "${RELEASE_ENV}" ]] || fatal "${RELEASE_ENV} not found"
    [[ -f "${VALUES_FILE}" ]] || fatal "${VALUES_FILE} not found"
    # shellcheck source=/dev/null
    source "${RELEASE_ENV}"
    [[ -n "${CHART:-}" && -n "${VERSION:-}" && -n "${NAMESPACE:-}" ]] \
        || fatal "${RELEASE_ENV} must define CHART, VERSION and NAMESPACE"
}

check_cluster() {
    task "kubernetes : cluster is reachable"
    if kubectl --context "${KUBE_CONTEXT}" get --raw=/readyz --request-timeout=10s > /dev/null 2>&1; then
        issue desired reachable "context ${KUBE_CONTEXT}"
        count checked
    else
        unreachable "cannot reach the API server of context ${KUBE_CONTEXT}"
    fi
}

# Prints the checksum of everything that defines the release
config_checksum() {
    { printf '%s\n%s\n%s\n' "${CHART}" "${VERSION}" "${NAMESPACE}"; cat "${VALUES_FILE}"; } \
        | sha256sum | cut -d' ' -f1
}

# Prints "<status> <description>" of the last revision, or nothing if the release does not exist
current_revision() {
    local history status description
    history="$(helm --kube-context "${KUBE_CONTEXT}" history "${RELEASE}" -n "${NAMESPACE}" --max 1 -o yaml 2> /dev/null)" || return 0
    status="$(sed -n 's/^  status: //p' <<< "${history}")"
    description="$(sed -n 's/^  description: //p' <<< "${history}")"
    printf '%s %s' "${status}" "${description}"
}

deploy_release() {
    local action="$1" checksum="$2" out
    detail "chart ${CHART} ${VERSION}, namespace ${NAMESPACE}"
    detail "waiting for pods to be ready (timeout ${HELM_TIMEOUT})"
    if out="$(helm --kube-context "${KUBE_CONTEXT}" upgrade --install "${RELEASE}" "${CHART}" \
        --version "${VERSION}" \
        --namespace "${NAMESPACE}" --create-namespace \
        --values "${VALUES_FILE}" \
        --description "config-sha256:${checksum}" \
        --atomic --wait --timeout "${HELM_TIMEOUT}" 2>&1)"; then
        log_file "${out}"
    else
        log_file "${out}"
        printf '%s\n' "${out}" >&2
        fatal "helm ${action} failed, release rolled back"
    fi
}

ensure_release() {
    task "helm : release ${RELEASE}"
    local checksum current
    checksum="$(config_checksum)"
    current="$(current_revision)"

    if [[ -z "${current}" ]]; then
        deploy_release install "${checksum}"
        issue change installed "${RELEASE} ${VERSION} in namespace ${NAMESPACE}"
        count installed
    elif [[ "${current}" == "deployed config-sha256:${checksum}" ]]; then
        issue desired unchanged "${RELEASE} ${VERSION}, config already deployed"
        count unchanged
    else
        detail "current revision: ${current}"
        deploy_release upgrade "${checksum}"
        issue change upgraded "${RELEASE} ${VERSION}"
        count upgraded
    fi
}

main() {
    (( $# == 1 )) || usage
    RELEASE="$1"
    readonly RELEASE
    init_log "helm-release.sh ${RELEASE}"
    RECAP_KEYS=(checked installed upgraded unchanged unreachable failed)

    require_cmd helm
    require_cmd kubectl
    load_release
    check_cluster
    ensure_release
    finish
}

main "$@"
