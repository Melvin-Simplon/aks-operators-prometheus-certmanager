#!/usr/bin/env bash
# Opens Grafana in the browser, with the admin password copied to the clipboard.
# The password is never printed nor written to the log.
# Usage: grafana.sh
# Env: KUBE_CONTEXT, DOMAIN, LOG_DIR, NO_BROWSER=1 to only print the URL
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_LABEL="grafana"
LOG_FILE="${LOG_DIR:-.logs}/grafana.log"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"
# shellcheck source=scripts/kube.sh
source "${SCRIPT_DIR}/kube.sh"
# shellcheck source=scripts/browser.sh
source "${SCRIPT_DIR}/browser.sh"

: "${DOMAIN:?DOMAIN must be set}"
readonly DOMAIN
readonly URL="https://${DOMAIN}"
readonly NAMESPACE="monitoring"
readonly SECRET="kube-prometheus-stack-grafana"

check_grafana() {
    task "network : grafana answers"
    if curl -sk --max-time 10 "${URL}/api/health" | grep -q '"database": *"ok"'; then
        issue desired healthy "${URL}"
        count healthy
    else
        unreachable "no healthy Grafana on ${URL}, check 'make status'"
    fi
}

# Prints the first clipboard command available, or nothing
clipboard_cmd() {
    local cmd
    for cmd in clip.exe wl-copy xclip pbcopy; do
        if command -v "${cmd}" > /dev/null; then
            [[ "${cmd}" == "xclip" ]] && cmd="xclip -selection clipboard"
            printf '%s' "${cmd}"
            return 0
        fi
    done
}

copy_password() {
    task "grafana : admin credentials"
    local user clip
    user="$(kctl -n "${NAMESPACE}" get secret "${SECRET}" -o jsonpath='{.data.admin-user}' 2> /dev/null | base64 -d)" \
        || fatal "secret ${NAMESPACE}/${SECRET} not found"
    clip="$(clipboard_cmd)"
    if [[ -z "${clip}" ]]; then
        issue skip skipping "no clipboard tool, user '${user}', password with:"
        detail "kubectl -n ${NAMESPACE} get secret ${SECRET} -o jsonpath='{.data.admin-password}' | base64 -d"
        count skipped
        return 0
    fi
    # Straight from the Secret to the clipboard: never in a variable, never on screen
    # shellcheck disable=SC2086 # clip may carry its own arguments
    kctl -n "${NAMESPACE}" get secret "${SECRET}" -o jsonpath='{.data.admin-password}' | base64 -d | ${clip}
    issue change copied "user '${user}', password copied to the clipboard"
    count copied
}

open_browser() {
    task "browser : open grafana"
    open_url "${URL}"
    detail "self-signed certificate: accept the browser warning"
}

main() {
    init_log "grafana.sh"
    RECAP_KEYS=(healthy copied opened skipped unreachable failed)

    require_cmd kubectl
    require_cmd curl
    check_cluster
    check_grafana
    copy_password
    open_browser
    finish
}

main "$@"
