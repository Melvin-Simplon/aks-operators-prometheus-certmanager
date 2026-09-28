#!/usr/bin/env bash
# Read-only health report of the whole stack: nodes, Helm releases, pods, certificates,
# public endpoint. Never changes anything, and does not stop at the first problem.
# Usage: status.sh
# Env: KUBE_CONTEXT, DOMAIN, LOG_DIR, CERT_WARN_DAYS
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
HOST_LABEL="status"
LOG_FILE="${LOG_DIR:-.logs}/status.log"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"
# shellcheck source=scripts/kube.sh
source "${SCRIPT_DIR}/kube.sh"
# shellcheck source=scripts/helm.sh
source "${SCRIPT_DIR}/helm.sh"

: "${DOMAIN:?DOMAIN must be set}"
: "${CERT_WARN_DAYS:=15}"
readonly DOMAIN CERT_WARN_DAYS

# Namespaces of the stack, besides the ones of the Helm releases
readonly EXTRA_NAMESPACES="monitoring"

healthy()   { issue desired "$1" "$2"; count healthy; }
outdated()  { issue change "$1" "$2"; count outdated; }
missing()   { issue fatal missing "$1"; count missing; }
unhealthy() { issue fatal "$1" "$2"; count unhealthy; }

# Prints the namespaces of the stack, one per line, sorted
stack_namespaces() {
    local release
    {
        while read -r release; do
            sed -n 's/^NAMESPACE=//p' "${ROOT_DIR}/helm/${release}/release.env"
        done < <(list_releases)
        tr ' ' '\n' <<< "${EXTRA_NAMESPACES}"
    } | sort -u
}

check_nodes() {
    task "kubernetes : nodes are ready"
    local name ready pool total=0 not_ready=()
    while read -r name ready pool; do
        total=$(( total + 1 ))
        [[ "${ready}" == "True" ]] || not_ready+=("${name} (${pool})")
    done < <(kctl get nodes --no-headers \
        -o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,POOL:.metadata.labels.agentpool')

    if (( ${#not_ready[@]} == 0 )); then
        healthy ready "${total}/${total} nodes"
    else
        unhealthy "not ready" "${not_ready[*]}"
    fi
}

check_release() {
    load_release
    local current status description
    current="$(current_revision)"
    status="${current%% *}"
    description="${current#* }"
    if [[ -z "${current}" ]]; then
        missing "${RELEASE} is not installed, run 'make ${RELEASE}'"
    elif [[ "${status}" != "deployed" ]]; then
        unhealthy "${status}" "${RELEASE}, last revision is ${status}"
    elif [[ "${description}" != "config-sha256:$(config_checksum)" ]]; then
        outdated outdated "${RELEASE} differs from helm/${RELEASE}/, run 'make ${RELEASE}'"
    else
        healthy deployed "${RELEASE} ${VERSION} (namespace ${NAMESPACE})"
    fi
}

check_releases() {
    task "helm : releases are deployed"
    local release
    while read -r release; do
        RELEASE="${release}"
        check_release
    done < <(list_releases)
}

# One verdict per namespace, Succeeded pods (jobs) are ignored
check_namespace_pods() {
    local namespace="$1" name phase ready total=0 ok=0 bad=()
    while read -r name phase ready; do
        [[ "${phase}" == "Succeeded" ]] && continue
        total=$(( total + 1 ))
        if [[ "${phase}" == "Running" && "${ready}" != *false* ]]; then
            ok=$(( ok + 1 ))
        else
            bad+=("${name} (${phase})")
        fi
    done < <(kctl get pods -n "${namespace}" --no-headers \
        -o custom-columns='NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[*].ready' 2> /dev/null)

    if (( total == 0 )); then
        issue skip skipping "${namespace}, no pod yet"
        count skipped
    elif (( ok == total )); then
        healthy running "${namespace} ${ok}/${total}"
    else
        unhealthy unhealthy "${namespace} ${ok}/${total}: ${bad[*]}"
    fi
}

check_pods() {
    task "kubernetes : pods are ready"
    local namespace
    while read -r namespace; do
        check_namespace_pods "${namespace}"
    done < <(stack_namespaces)
}

# Visual summary: one node table and one pod table for the whole stack
print_resources() {
    header "RESOURCES"
    local -A pool_of=()
    local name pool vm ready version namespace phase readies restarts node line
    local rows=("NODE POOL VM READY VERSION")
    while read -r name pool vm ready version; do
        pool_of["${name}"]="${pool}"
        rows+=("${name} ${pool} ${vm} ${ready} ${version}")
    done < <(kctl get nodes --no-headers -o custom-columns='NAME:.metadata.name,POOL:.metadata.labels.agentpool,VM:.metadata.labels.node\.kubernetes\.io/instance-type,READY:.status.conditions[?(@.type=="Ready")].status,VERSION:.status.nodeInfo.kubeletVersion')
    printf '\n'
    while IFS= read -r line; do detail "${line}"; done < <(printf '%s\n' "${rows[@]}" | column -t)

    rows=("NAMESPACE POD READY STATUS RESTARTS POOL")
    while read -r namespace; do
        while read -r name phase readies restarts node; do
            rows+=("${namespace} ${name} $(ready_ratio "${readies}") ${phase} $(sum_list "${restarts}") ${pool_of[${node}]:-${node}}")
        done < <(kctl get pods -n "${namespace}" --no-headers -o custom-columns='NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[*].ready,RESTARTS:.status.containerStatuses[*].restartCount,NODE:.spec.nodeName' 2> /dev/null)
    done < <(stack_namespaces)
    printf '\n'
    if (( ${#rows[@]} > 1 )); then
        while IFS= read -r line; do detail "${line}"; done < <(printf '%s\n' "${rows[@]}" | column -t)
    else
        detail "no pod in the stack namespaces"
    fi
}

# "true,false,true" -> "2/3"
ready_ratio() {
    local list="$1" total ok
    [[ "${list}" == "<none>" ]] && { printf '0/0'; return; }
    total="$(tr ',' '\n' <<< "${list}" | grep -c .)"
    ok="$(tr ',' '\n' <<< "${list}" | grep -c '^true$' || true)"
    printf '%s/%s' "${ok}" "${total}"
}

# "0,2,1" -> "3"
sum_list() {
    local list="$1" n sum=0
    [[ "${list}" == "<none>" ]] && { printf '0'; return; }
    for n in ${list//,/ }; do sum=$(( sum + n )); done
    printf '%s' "${sum}"
}

check_certificates() {
    task "cert-manager : certificates are valid"
    if ! kctl get crd certificates.cert-manager.io > /dev/null 2>&1; then
        issue skip skipping "cert-manager CRDs are not installed"
        count skipped
        return 0
    fi
    local namespace name ready not_after days_left found=false
    while read -r namespace name ready not_after; do
        found=true
        if [[ "${ready}" != "True" ]]; then
            unhealthy "not ready" "${namespace}/${name}"
            continue
        fi
        days_left=$(( ( $(date -d "${not_after}" +%s) - $(date +%s) ) / 86400 ))
        if (( days_left < CERT_WARN_DAYS )); then
            outdated expiring "${namespace}/${name} expires ${not_after%T*} (${days_left} days left)"
        else
            healthy valid "${namespace}/${name} until ${not_after%T*} (${days_left} days left)"
        fi
    done < <(kctl get certificates -A --no-headers \
        -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,NOTAFTER:.status.notAfter')

    if [[ "${found}" == "false" ]]; then
        issue skip skipping "no certificate defined"
        count skipped
    fi
}

check_endpoint() {
    task "network : public endpoint answers"
    local code subject
    code="$(curl -sk -o /dev/null -w '%{http_code}' --max-time 10 "https://${DOMAIN}/" || true)"
    if [[ -z "${code}" || "${code}" == "000" ]]; then
        issue unreachable unreachable "no answer on https://${DOMAIN}"
        count unreachable
        return 0
    fi
    subject="$(openssl s_client -connect "${DOMAIN}:443" -servername "${DOMAIN}" < /dev/null 2> /dev/null \
        | openssl x509 -noout -subject 2> /dev/null || true)"
    healthy responding "https://${DOMAIN} HTTP ${code}, certificate ${subject#subject=}"
}

main() {
    (( $# == 0 )) || { printf 'Usage: %s\n' "$(basename "$0")" >&2; exit 2; }
    init_log "status.sh"
    RECAP_KEYS=(healthy outdated missing unhealthy unreachable skipped)
    FAILURE_KEYS=(missing unhealthy failed)

    require_cmd kubectl
    require_cmd helm
    require_cmd curl
    require_cmd openssl
    check_cluster
    check_nodes
    check_releases
    check_pods
    check_certificates
    check_endpoint
    print_resources
    finish
}

main "$@"
