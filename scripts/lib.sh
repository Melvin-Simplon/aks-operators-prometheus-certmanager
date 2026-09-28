#!/usr/bin/env bash
# Shared helpers, sourced and never executed.
# Console output follows Ansible: TASK headers, one issue per line, PLAY RECAP.
# Issue words and recap counters are chosen by each script, after the tool it runs.

shopt -s extglob

: "${LOG_FILE:=.logs/run.log}"
: "${HOST_LABEL:=local}"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    readonly C_GREEN=$'\e[32m' C_YELLOW=$'\e[33m' C_CYAN=$'\e[36m' \
        C_BRIGHT_RED=$'\e[1;31m' C_RED=$'\e[31m' C_BOLD=$'\e[1m' C_RESET=$'\e[0m'
else
    readonly C_GREEN='' C_YELLOW='' C_CYAN='' C_BRIGHT_RED='' C_RED='' C_BOLD='' C_RESET=''
fi

# Recap counters, in display order. Scripts override RECAP_KEYS with their own words.
# count() updates them, so never call it (or anything calling it) in $(...)
RECAP_KEYS=(ok changed unreachable failed skipped)
declare -A COUNTERS=()

# Append one timestamped line to the log, without ANSI sequences
log_file() {
    local line="${1//$'\e'\[*([0-9;])m/}"
    printf '%(%F %T)T %s\n' -1 "${line}" >> "${LOG_FILE}"
}

init_log() {
    mkdir -p "$(dirname "${LOG_FILE}")"
    touch "${LOG_FILE}"
    chmod 600 "${LOG_FILE}"
    log_file "===== run: $* ====="
}

# Print "<title> ****" padded to 80 columns, like Ansible headers
header() {
    local title="$1" stars
    stars="$(printf '%*s' $(( 79 - ${#title} > 3 ? 79 - ${#title} : 3 )) '' | tr ' ' '*')"
    printf '\n%s%s %s%s\n' "${C_BOLD}" "${title}" "${stars}" "${C_RESET}"
    log_file "${title}"
}

task() { header "TASK [$1]"; }

count() {
    COUNTERS[$1]=$(( ${COUNTERS[$1]:-0} + ${2:-1} ))
}

# issue <kind> <word> <message>: one result line
# kind sets the color: desired (green), change (yellow), skip (cyan), unreachable, fatal (stderr)
issue() {
    local color line
    case "$1" in
        desired)     color="${C_GREEN}" ;;
        change)      color="${C_YELLOW}" ;;
        skip)        color="${C_CYAN}" ;;
        unreachable) color="${C_BRIGHT_RED}" ;;
        fatal)       color="${C_RED}" ;;
        *)           color="" ;;
    esac
    line="$(printf '%-12s [%s] %s' "$2:" "${HOST_LABEL}" "$3")"
    if [[ "$1" == "unreachable" || "$1" == "fatal" ]]; then
        printf '%s%s%s\n' "${color}" "${line}" "${C_RESET}" >&2
    else
        printf '%s%s%s\n' "${color}" "${line}" "${C_RESET}"
    fi
    log_file "${line}"
}

detail() {
    printf '    %s\n' "$1"
    log_file "    $1"
}

warning() {
    printf '%s[WARNING]: %s%s\n' "${C_YELLOW}" "$1" "${C_RESET}" >&2
    log_file "[WARNING]: $1"
}

play_recap() {
    header "PLAY RECAP"
    local line key
    line="$(printf '%-12s:' "${HOST_LABEL}")"
    for key in "${RECAP_KEYS[@]}"; do
        line+="$(printf ' %s=%-4s' "${key}" "${COUNTERS[${key}]:-0}")"
    done
    line="${line%%+( )}"
    printf '%s\n' "${line}"
    log_file "${line}"
}

# Recap, then exit: non-zero when something failed or was unreachable, skipped never fails
finish() {
    play_recap
    if (( ${COUNTERS[unreachable]:-0} > 0 )); then
        exit 4
    elif (( ${COUNTERS[failed]:-0} > 0 )); then
        exit "${1:-1}"
    fi
    exit 0
}

# fatal <message> [exit code]
fatal() {
    issue fatal fatal "$1"
    count failed
    finish "${2:-1}"
}

unreachable() {
    issue unreachable unreachable "$1"
    count unreachable
    finish
}

# Run a command, show its output and copy it to the log. Keeps the command exit code.
run_logged() {
    local line
    "$@" 2>&1 | while IFS= read -r line; do
        printf '%s\n' "${line}"
        log_file "${line}"
    done
}

require_cmd() {
    command -v "$1" > /dev/null || fatal "'$1' not found in PATH"
}
