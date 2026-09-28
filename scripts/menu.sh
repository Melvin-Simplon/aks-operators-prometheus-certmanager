#!/usr/bin/env bash
# Interactive menu of the make targets, built from the "##@ section" and
# "target: ## description" lines, so it never drifts from the real targets.
# Two levels: the main menu lists the sections, each section opens a sub-menu of its targets.
# Without a terminal it only prints the full list.
# Usage: menu.sh <makefile> [<makefile>...]   (the Makefile passes $(MAKEFILE_LIST))
# Env: MAKE, KUBE_CONTEXT, DOMAIN, NO_COLOR
set -euo pipefail
shopt -s extglob

: "${MAKE:=make}"

# Section display order, unknown sections come last
readonly SECTION_ORDER=("Azure infrastructure" "Deploy the stack" "Access" "Checks")
# One accent color (256 color code, purple) and a grey for descriptions
readonly ACCENT=141
readonly MUTED=245
readonly WARNING=214

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    COLOR=true
else
    COLOR=false
fi

SECTIONS=()
declare -A TARGETS_OF=()
declare -A DESCRIPTION_OF=()
MENU_SECTIONS=()
MENU_TARGETS=()
TARGETS=()
BANNER_LINES=()

usage() {
    printf 'Usage: %s <makefile> [<makefile>...]\n' "$(basename "$0")" >&2
    exit 2
}

# fg <256 color code>: prints the escape sequence, or nothing without colors
fg() {
    [[ "${COLOR}" == "true" ]] && printf '\e[38;5;%sm' "$1"
    return 0
}

bold()  { [[ "${COLOR}" == "true" ]] && printf '\e[1m'; return 0; }

# heading <text>: bold and accent color in a single sequence, some terminals drop a separate bold
heading() {
    if [[ "${COLOR}" == "true" ]]; then
        printf '\e[1;38;5;%sm%s\e[0m' "${ACCENT}" "$1"
    else
        printf '%s' "$1"
    fi
}
reset() { [[ "${COLOR}" == "true" ]] && printf '\e[0m'; return 0; }

# Reads every makefile, a section declared in several files is merged
parse_targets() {
    local file line section="Other" target
    for file in "$@"; do
        [[ -f "${file}" ]] || continue
        while IFS= read -r line; do
            if [[ "${line}" =~ ^##@\ (.+)$ ]]; then
                section="${BASH_REMATCH[1]}"
                [[ -v "TARGETS_OF[${section}]" ]] || { SECTIONS+=("${section}"); TARGETS_OF["${section}"]=""; }
            elif [[ "${line}" =~ ^([a-zA-Z0-9_-]+):[^#]*##\ (.+)$ ]]; then
                target="${BASH_REMATCH[1]}"
                [[ "${target}" == "menu" ]] && continue
                [[ -v "TARGETS_OF[${section}]" ]] || { SECTIONS+=("${section}"); TARGETS_OF["${section}"]=""; }
                TARGETS_OF["${section}"]+="${target} "
                DESCRIPTION_OF["${target}"]="${BASH_REMATCH[2]}"
            fi
        done < "${file}"
    done
}

# Sections of SECTION_ORDER first, in that order, then the others as found
ordered_sections() {
    local section known known_section
    for section in "${SECTION_ORDER[@]}"; do
        [[ -v "TARGETS_OF[${section}]" ]] && printf '%s\n' "${section}"
    done
    for section in "${SECTIONS[@]}"; do
        known=false
        for known_section in "${SECTION_ORDER[@]}"; do
            [[ "${section}" == "${known_section}" ]] && known=true
        done
        [[ "${known}" == "true" ]] || printf '%s\n' "${section}"
    done
}

# Braille art, drawn on the left of the menu when the terminal is wide enough.
# Every line is ART_WIDTH braille characters wide.
readonly ART_WIDTH=30
# Vertical gradient of the art, top to bottom (256 color codes, deep purple to lavender)
readonly ART_GRADIENT=(93 99 135 141 177 183)
mapfile -t ART <<'EOF'
⠀⠀⠀⠀⠀⢸⠓⢄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⢸⠀⠀⠑⢤⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⢸⡆⠀⠀⠀⠙⢤⡷⣤⣦⣀⠤⠖⠚⡿⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀
⣠⡿⠢⢄⡀⠀⡇⠀⠀⠀⠀⠀⠉⠀⠀⠀⠀⠀⠸⠷⣶⠂⠀⠀⠀⣀⣀⠀⠀⠀
⢸⣃⠀⠀⠉⠳⣷⠞⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠉⠉⠉⠉⠉⠉⢉⡭⠋
⠀⠘⣆⠀⠀⠀⠁⠀⢀⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡴⠋⠀⠀
⠀⠀⠘⣦⠆⠀⠀⢀⡎⢹⡀⠀⠀⠀⠀⠀⠀⠀⠀⡀⠀⠀⡀⣠⠔⠋⠀⠀⠀⠀
⠀⠀⠀⡏⠀⠀⣆⠘⣄⠸⢧⠀⠀⠀⠀⢀⣠⠖⢻⠀⠀⠀⣿⢥⣄⣀⣀⣀⠀⠀
⠀⠀⢸⠁⠀⠀⡏⢣⣌⠙⠚⠀⠀⠠⣖⡛⠀⣠⠏⠀⠀⠀⠇⠀⠀⠀⠀⢙⣣⠄
⠀⠀⢸⡀⠀⠀⠳⡞⠈⢻⠶⠤⣄⣀⣈⣉⣉⣡⡔⠀⠀⢀⠀⠀⣀⡤⠖⠚⠀⠀
⠀⠀⡼⣇⠀⠀⠀⠙⠦⣞⡀⠀⢀⡏⠀⢸⣣⠞⠀⠀⠀⡼⠚⠋⠁⠀⠀⠀⠀⠀
⠀⢰⡇⠙⠀⠀⠀⠀⠀⠀⠉⠙⠚⠒⠚⠉⠀⠀⠀⠀⡼⠁⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⢧⡀⠀⢠⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⣞⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠙⣶⣶⣿⠢⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠉⠀⠀⠀⠙⢿⣳⠞⠳⡄⠀⠀⠀⢀⡞⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠀⠀⠹⣄⣀⡤⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
EOF
readonly ART

# "Menu" title, printed above the art and the menu with the same gradient
mapfile -t BANNER <<'EOF'
██▄  ▄██  ▄▄▄  ▄▄ ▄▄ ▄▄▄▄▄ ▄▄▄▄▄ ▄▄ ▄▄    ▄▄▄▄▄
██ ▀▀ ██ ██▀██ ██▄█▀ ██▄▄  ██▄▄  ██ ██    ██▄▄
██    ██ ██▀██ ██ ██ ██▄▄▄ ██    ██ ██▄▄▄ ██▄▄▄

EOF
readonly BANNER

# gradient_row <row> <row count> <text>: bold, colored with the gradient step of that row
gradient_row() {
    local color="${ART_GRADIENT[$1 * ${#ART_GRADIENT[@]} / $2]:-${ACCENT}}"
    if [[ "${COLOR}" == "true" ]]; then
        printf '\e[1;38;5;%sm%s\e[0m' "${color}" "$3"
    else
        printf '%s' "$3"
    fi
}

# banner_lines: fills BANNER_LINES with the colored "Menu" title, one entry per row
banner_lines() {
    local i
    BANNER_LINES=()
    for (( i = 0; i < ${#BANNER[@]}; i++ )); do
        BANNER_LINES+=("$(gradient_row "${i}" "${#BANNER[@]}" "${BANNER[i]}")")
    done
}

# art_row <row> <text>: bold, colored with the gradient step of that row
art_row() {
    local color="${ART_GRADIENT[$1 * ${#ART_GRADIENT[@]} / ${#ART[@]}]:-${ACCENT}}"
    if [[ "${COLOR}" == "true" ]]; then
        printf '\e[1;38;5;%sm%s\e[0m' "${color}" "$2"
    else
        printf '%s' "$2"
    fi
}

# Quick infra facts under the title, read once when the menu opens (see load_infra_info)
INFO_CLUSTER=""
INFO_IP=""

load_infra_info() {
    local nodes ready
    if nodes="$(kubectl --context "${KUBE_CONTEXT:-}" get nodes --no-headers --request-timeout=3s 2> /dev/null)"; then
        ready="$(grep -c ' Ready ' <<< "${nodes}" || true)"
        INFO_CLUSTER="${KUBE_CONTEXT:-?}, ${ready}/$(grep -c . <<< "${nodes}") nodes ready"
    else
        INFO_CLUSTER="$(fg "${WARNING}")${KUBE_CONTEXT:-?} unreachable$(reset)"
    fi
    INFO_IP="$(getent hosts "${DOMAIN:-}" 2> /dev/null | awk '{ print $1; exit }')"
    : "${INFO_IP:=unknown}"
}

# info_line <label> <value>
info_line() {
    printf ' %s%-8s%s %s' "$(fg "${ACCENT}")" "$1" "$(reset)" "$2"
}

# render <line>...: prints the title, the infra facts, then the lines, as the right column next to the art
# when the terminal is wide enough
render() {
    local lines=() line plain width=0 i rows columns blank offset
    banner_lines
    lines=("${BANNER_LINES[@]}"
        "$(info_line Cluster "${INFO_CLUSTER}")"
        "$(info_line Grafana "https://${DOMAIN:-?}")"
        "$(info_line "LB IP" "${INFO_IP}")"
        "" "$@")
    for line in "${lines[@]}"; do
        plain="${line//$'\e'\[*([0-9;])m/}"
        (( ${#plain} > width )) && width="${#plain}"
    done
    columns="$(tput cols 2> /dev/null || printf '80')"

    printf '\n'
    if (( columns < 2 + ART_WIDTH + 3 + width )); then
        printf '  %s\n' "${lines[@]}"
    else
        # Center the menu vertically next to the art
        offset=$(( (${#ART[@]} - ${#lines[@]}) / 2 ))
        if (( offset > 0 )); then
            for (( i = 0; i < offset; i++ )); do lines=("" "${lines[@]}"); done
        fi
        rows=$(( ${#lines[@]} > ${#ART[@]} ? ${#lines[@]} : ${#ART[@]} ))
        # Padding under the art: braille blanks (U+2800), the same glyph as the art
        blank=""
        for (( i = 0; i < ART_WIDTH; i++ )); do blank+="⠀"; done
        for (( i = 0; i < rows; i++ )); do
            printf '  %s   %s\n' "$(art_row "${i}" "${ART[i]:-${blank}}")" "${lines[i]:-}"
        done
    fi
    printf '\n'
}

# item_line <number> <name> <description>: one numbered entry
item_line() {
    printf ' %s%2d%s  %-20s %s%s%s' "$(fg "${ACCENT}")" "$1" "$(reset)" "$2" "$(fg "${MUTED}")" "$3" "$(reset)"
}

# section_targets <section>: fills TARGETS with the targets of the section
section_targets() {
    read -ra TARGETS <<< "${TARGETS_OF[$1]}"
}

# Main menu: one entry per section, listing its targets. Fills MENU_SECTIONS (index = number - 1)
# Main menu: one entry per section. Fills MENU_SECTIONS (index = number - 1)
print_main() {
    local section lines=() number=0
    MENU_SECTIONS=()
    while IFS= read -r section; do
        number=$(( number + 1 ))
        MENU_SECTIONS+=("${section}")
        (( number > 1 )) && lines+=("")
        lines+=("$(printf ' %s%2d%s  %s' "$(fg "${ACCENT}")" "${number}" "$(reset)" "$(heading "${section}")")")
    done < <(ordered_sections)
    render "${lines[@]}"
}

# Sub-menu of one section. Fills MENU_TARGETS (index = number - 1)
print_section() {
    local target lines=() number=0
    MENU_TARGETS=()
    lines+=("$(heading "$1")" "")
    section_targets "$1"
    for target in "${TARGETS[@]}"; do
        number=$(( number + 1 ))
        MENU_TARGETS+=("${target}")
        lines+=("$(item_line "${number}" "${target}" "${DESCRIPTION_OF[${target}]}")")
    done
    render "${lines[@]}"
}

# Full list without numbers, for a run without terminal (CI, docs)
print_all() {
    local section target
    while IFS= read -r section; do
        printf '\n  %s\n' "${section}"
        section_targets "${section}"
        for target in "${TARGETS[@]}"; do
            printf '    %-20s %s\n' "${target}" "${DESCRIPTION_OF[${target}]}"
        done
    done < <(ordered_sections)
    printf '\n'
}

# ask <max> <main|sub>: prints the chosen number, "b" (back, sub-menu only) or "q" (quit).
# Enter alone quits the main menu and goes back from a sub-menu.
ask() {
    local max="$1" level="$2" answer prompt
    if [[ "${level}" == "main" ]]; then
        prompt="Choose a theme (q to quit): "
    else
        prompt="Choose a command (b to go back, q to quit): "
    fi
    while true; do
        read -r -p "  $(fg "${ACCENT}")${prompt}$(reset)" answer < /dev/tty || { printf 'q'; return 0; }
        answer="${answer//[[:space:]]/}"
        case "${answer,,}" in
            q) printf 'q'; return 0 ;;
            "")
                if [[ "${level}" == "main" ]]; then printf 'q'; else printf 'b'; fi
                return 0
                ;;
            b)
                if [[ "${level}" == "sub" ]]; then printf 'b'; return 0; fi
                ;;
        esac
        if [[ "${answer}" =~ ^[0-9]+$ ]] && (( answer >= 1 && answer <= max )); then
            printf '%s' "${answer}"
            return 0
        fi
        printf '  %sNothing at %s, pick 1 to %d.%s\n' "$(fg "${MUTED}")" "${answer}" "${max}" "$(reset)" >&2
    done
}

run_target() {
    printf '\n  %s> make %s%s\n' "$(fg "${ACCENT}")" "$1" "$(reset)"
    # Ctrl+C stops the target (port-forward...) and comes back to the menu
    "${MAKE}" --no-print-directory "$1" || true
    read -r -p "  $(fg "${MUTED}")Press Enter to go back $(reset)" _ < /dev/tty || true
}

# clear_screen: only in the interactive loop, outside a terminal clear prints escape codes
# and it fails (set -e) when TERM is unset
clear_screen() {
    clear 2> /dev/null || true
}

# sub_menu <section>: loops on the targets of the section. Returns 1 when the user quits.
sub_menu() {
    local choice
    while true; do
        clear_screen
        print_section "$1"
        choice="$(ask "${#MENU_TARGETS[@]}" sub)"
        case "${choice}" in
            q) return 1 ;;
            b) return 0 ;;
        esac
        run_target "${MENU_TARGETS[choice - 1]}"
    done
}

main() {
    (( $# >= 1 )) || usage
    parse_targets "$@"

    if [[ ! -t 0 || ! -t 1 ]]; then
        print_all
        return 0
    fi

    trap 'printf "\n"' INT
    load_infra_info
    local choice
    while true; do
        clear_screen
        print_main
        choice="$(ask "${#MENU_SECTIONS[@]}" main)"
        [[ "${choice}" == "q" ]] && break
        sub_menu "${MENU_SECTIONS[choice - 1]}" || break
    done
}

main "$@"
