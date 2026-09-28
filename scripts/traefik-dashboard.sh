#!/usr/bin/env bash
# Opens the Traefik dashboard through a port-forward, the dashboard is never exposed publicly.
# Usage: traefik-dashboard.sh
# Env: KUBE_CONTEXT, LOG_DIR, LOCAL_PORT
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_LABEL="traefik"
LOG_FILE="${LOG_DIR:-.logs}/traefik.log"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"
# shellcheck source=scripts/kube.sh
source "${SCRIPT_DIR}/kube.sh"

: "${LOCAL_PORT:=9000}"
readonly LOCAL_PORT
readonly NAMESPACE="traefik"
readonly DASHBOARD_PORT=8080

check_deployment() {
    task "kubernetes : traefik is running"
    if kctl -n "${NAMESPACE}" rollout status deployment/traefik --timeout=10s > /dev/null 2>&1; then
        issue desired running "deployment/traefik in namespace ${NAMESPACE}"
    else
        fatal "deployment/traefik is not ready, run 'make traefik'"
    fi
}

open_tunnel() {
    task "kubectl : port-forward to the dashboard"
    issue desired listening "http://localhost:${LOCAL_PORT}/dashboard/ (Ctrl+C to stop)"
    kctl -n "${NAMESPACE}" port-forward deployment/traefik "${LOCAL_PORT}:${DASHBOARD_PORT}" > /dev/null
}

main() {
    init_log "traefik-dashboard.sh"
    require_cmd kubectl
    check_cluster
    check_deployment
    open_tunnel
}

main "$@"
