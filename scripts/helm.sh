#!/usr/bin/env bash
# Helm release helpers, sourced after lib.sh and kube.sh, never executed.
# A release is defined by helm/<release>/release.env (CHART, VERSION, NAMESPACE) and values.yaml.

# Prints the release names defined under helm/, one per line
list_releases() {
    local env_file
    for env_file in "${ROOT_DIR}"/helm/*/release.env; do
        [[ -f "${env_file}" ]] || continue
        basename "$(dirname "${env_file}")"
    done
}

# Loads helm/<RELEASE>/ into CHART, VERSION, NAMESPACE, VALUES_FILE
load_release() {
    local release_dir="${ROOT_DIR}/helm/${RELEASE}" release_env
    release_env="${release_dir}/release.env"
    VALUES_FILE="${release_dir}/values.yaml"
    [[ -f "${release_env}" ]] || fatal "${release_env} not found"
    [[ -f "${VALUES_FILE}" ]] || fatal "${VALUES_FILE} not found"
    CHART="" VERSION="" NAMESPACE=""
    # shellcheck source=/dev/null
    source "${release_env}"
    [[ -n "${CHART}" && -n "${VERSION}" && -n "${NAMESPACE}" ]] \
        || fatal "${release_env} must define CHART, VERSION and NAMESPACE"
}

# Prints the checksum of everything that defines the loaded release
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
