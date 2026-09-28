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
# shellcheck source=scripts/kube.sh
source "${SCRIPT_DIR}/kube.sh"
# shellcheck source=scripts/helm.sh
source "${SCRIPT_DIR}/helm.sh"

: "${HELM_TIMEOUT:=5m}"
readonly HELM_TIMEOUT

usage() {
    printf 'Usage: %s <release>\n' "$(basename "$0")" >&2
    exit 2
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
