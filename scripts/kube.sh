#!/usr/bin/env bash
# Kubernetes helpers, sourced after lib.sh and never executed.

: "${KUBE_CONTEXT:?KUBE_CONTEXT must be set}"

kctl() {
    kubectl --context "${KUBE_CONTEXT}" "$@"
}

check_cluster() {
    task "kubernetes : cluster is reachable"
    if kctl get --raw=/readyz --request-timeout=10s > /dev/null 2>&1; then
        issue desired reachable "context ${KUBE_CONTEXT}"
        count checked
    else
        unreachable "cannot reach the API server of context ${KUBE_CONTEXT}"
    fi
}
