#!/usr/bin/env bash
# Browser helper, sourced after lib.sh and never executed.

# Prints the first browser opener available, or nothing
browser_cmd() {
    local cmd
    for cmd in wslview explorer.exe xdg-open open; do
        if command -v "${cmd}" > /dev/null; then
            printf '%s' "${cmd}"
            return 0
        fi
    done
}

# open_url <url>: opens it in the browser, reports opened or skipping.
# NO_BROWSER=1 only prints the URL.
open_url() {
    local url="$1" opener
    opener="$(browser_cmd)"
    if [[ "${NO_BROWSER:-0}" == "1" || -z "${opener}" ]]; then
        issue skip skipping "open ${url} yourself"
        count skipped
        return 0
    fi
    # explorer.exe returns 1 even when the browser opens
    "${opener}" "${url}" > /dev/null 2>&1 || true
    issue change opened "${url}"
    count opened
}
