#!/usr/bin/env bash
# Interactive menu of the make targets, grouped by section (##@) and built from the
# "target: ## description" lines, so it never drifts from the real targets.
# Without a terminal it only prints the list.
# Usage: menu.sh <makefile> [<makefile>...]   (the Makefile passes $(MAKEFILE_LIST))
# Env: MAKE, NO_COLOR
set -euo pipefail

: "${MAKE:=make}"

# Section display order, unknown sections come last
readonly SECTION_ORDER=("Azure infrastructure" "Deploy the stack" "Access" "Checks")
# One accent color (256 color code, purple) and a grey for descriptions
readonly ACCENT=141
readonly MUTED=245

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    COLOR=true
else
    COLOR=false
fi

SECTIONS=()
declare -A TARGETS_OF=()
declare -A DESCRIPTION_OF=()
MENU_TARGETS=()

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

# Width of a menu line without colors: indent, number, target column, description
menu_width() {
    local target width=0 line_width
    for target in "${!DESCRIPTION_OF[@]}"; do
        line_width=$(( 26 + ${#DESCRIPTION_OF[${target}]} ))
        (( line_width > width )) && width="${line_width}"
    done
    printf '%s' "${width}"
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

# Prints the numbered menu, the art on the left, and fills MENU_TARGETS (index = number - 1)
print_menu() {
    local section target number=0 targets=() lines=() i rows columns show_art=false blank
    MENU_TARGETS=()

    while IFS= read -r section; do
        (( ${#lines[@]} > 0 )) && lines+=("")
        lines+=("$(heading "${section}")")
        read -ra targets <<< "${TARGETS_OF[${section}]}"
        for target in "${targets[@]}"; do
            number=$(( number + 1 ))
            MENU_TARGETS+=("${target}")
            lines+=("$(printf ' %s%2d%s  %-18s %s%s%s' \
                "$(fg "${ACCENT}")" "${number}" "$(reset)" "${target}" \
                "$(fg "${MUTED}")" "${DESCRIPTION_OF[${target}]}" "$(reset)")")
        done
    done < <(ordered_sections)

    columns="$(tput cols 2> /dev/null || printf '80')"
    if (( columns >= 2 + ART_WIDTH + 3 + $(menu_width) )); then
        show_art=true
    fi

    printf '\n'
    if [[ "${show_art}" == "false" ]]; then
        printf '  %s\n' "${lines[@]}"
    else
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

# Prints the chosen target, or nothing to quit
read_choice() {
    local answer
    while true; do
        read -r -p "  $(fg "${ACCENT}")Choose a number (q to quit): $(reset)" answer < /dev/tty || return 0
        answer="${answer//[[:space:]]/}"
        case "${answer}" in
            q | Q | "") return 0 ;;
        esac
        if [[ "${answer}" =~ ^[0-9]+$ ]] && (( answer >= 1 && answer <= ${#MENU_TARGETS[@]} )); then
            printf '%s' "${MENU_TARGETS[answer - 1]}"
            return 0
        fi
        printf '  %sNo target %s, pick 1 to %d.%s\n' "$(fg "${MUTED}")" "${answer}" "${#MENU_TARGETS[@]}" "$(reset)" >&2
    done
}

run_target() {
    printf '\n  %s> make %s%s\n' "$(fg "${ACCENT}")" "$1" "$(reset)"
    # Ctrl+C stops the target (port-forward...) and comes back to the menu
    "${MAKE}" --no-print-directory "$1" || true
    read -r -p "  $(fg "${MUTED}")Press Enter to go back to the menu $(reset)" _ < /dev/tty || true
}

main() {
    (( $# >= 1 )) || usage
    parse_targets "$@"

    if [[ ! -t 0 || ! -t 1 ]]; then
        print_menu
        return 0
    fi

    trap 'printf "\n"' INT
    local target
    while true; do
        # Only here, in the interactive loop: outside a terminal clear prints escape codes,
        # and it fails (set -e) when TERM is unset
        clear 2> /dev/null || true
        print_menu
        target="$(read_choice)"
        [[ -n "${target}" ]] || break
        run_target "${target}"
    done
}

main "$@"
