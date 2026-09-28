#!/usr/bin/env bash
# Opens web UIs that are not exposed publicly, through kubectl port-forward, then keeps the
# tunnels open until Ctrl+C, which closes all of them.
# Usage: open-ui.sh <ui> [<ui>...]    ui: prometheus, alertmanager, traefik
# Env: KUBE_CONTEXT, LOG_DIR, NO_BROWSER=1 to only print the URLs, NO_WAIT=1 to close at once
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_LABEL="ui"
LOG_FILE="${LOG_DIR:-.logs}/ui.log"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"
# shellcheck source=scripts/kube.sh
source "${SCRIPT_DIR}/kube.sh"
# shellcheck source=scripts/browser.sh
source "${SCRIPT_DIR}/browser.sh"

# name = namespace, target, local port, remote port, path to open, text the page must contain
declare -A UIS=(
    [prometheus]="monitoring svc/kube-prometheus-stack-prometheus 9090 9090 /alerts Prometheus"
    [alertmanager]="monitoring svc/kube-prometheus-stack-alertmanager 9093 9093 / Alertmanager"
    [traefik]="traefik deployment/traefik 9000 8080 /dashboard/ Traefik"
)
readonly UIS

TUNNEL_PIDS=()

usage() {
    printf 'Usage: %s <ui> [<ui>...]   ui: %s\n' "$(basename "$0")" "${!UIS[*]}" >&2
    exit 2
}

# shellcheck disable=SC2317 # called by the EXIT trap
stop_tunnels() {
    local pid
    for pid in "${TUNNEL_PIDS[@]}"; do
        kill "${pid}" 2> /dev/null || true
    done
}

# page_answers <port> <path> <text>: the local page answers and looks like the expected UI
page_answers() {
    curl -s --max-time 2 "http://localhost:$1$2" 2> /dev/null | grep -qi "$3"
}

port_busy() {
    (: < "/dev/tcp/127.0.0.1/$1") 2> /dev/null
}

open_ui() {
    local name="$1" namespace target port remote path text url i
    read -r namespace target port remote path text <<< "${UIS[${name}]}"
    url="http://localhost:${port}${path}"
    task "kubectl : port-forward ${name}"

    if page_answers "${port}" "${path}" "${text}"; then
        issue desired forwarded "${url} (tunnel already open)"
        count forwarded
    elif port_busy "${port}"; then
        issue fatal busy "port ${port} is used by something else, free it and retry"
        count failed
        return 0
    elif ! kctl -n "${namespace}" get "${target}" > /dev/null 2>&1; then
        issue fatal missing "${namespace}/${target} not found"
        count failed
        return 0
    else
        # kubectl itself, not the kctl function: $! must be the kubectl PID to kill it later
        kubectl --context "${KUBE_CONTEXT}" -n "${namespace}" port-forward "${target}" "${port}:${remote}" > /dev/null 2>&1 &
        TUNNEL_PIDS+=("$!")
        for (( i = 0; i < 20; i++ )); do
            page_answers "${port}" "${path}" "${text}" && break
            sleep 0.5
        done
        if ! page_answers "${port}" "${path}" "${text}"; then
            issue fatal failed "${name} does not answer on ${url}"
            count failed
            return 0
        fi
        issue change forwarded "${url}"
        count forwarded
    fi
    open_url "${url}"
}

main() {
    (( $# >= 1 )) || usage
    local name
    for name in "$@"; do
        [[ -v "UIS[${name}]" ]] || usage
    done
    init_log "open-ui.sh $*"
    RECAP_KEYS=(forwarded opened skipped unreachable failed)

    require_cmd kubectl
    require_cmd curl
    trap stop_tunnels EXIT
    check_cluster
    for name in "$@"; do
        open_ui "${name}"
    done

    if (( ${COUNTERS[failed]:-0} > 0 )) || (( ${#TUNNEL_PIDS[@]} == 0 )) || [[ "${NO_WAIT:-0}" == "1" ]]; then
        finish
    fi
    play_recap
    printf '\n    Tunnels open, Ctrl+C to close them all\n'
    trap 'stop_tunnels; printf "\n"; exit 0' INT
    wait
}

main "$@"
