#!/usr/bin/env bash

# tmux_menu.sh - interactive selector for tmux sessions.

set -euo pipefail
IFS=$'\n\t'

readonly MENU_ARROW_TIMEOUT=1
readonly BANNER_LINE="============================================================="
readonly BANNER_TITLE="Tmux Sessions"

log_info() {
  printf "[INFO] %s\n" "$*"
}

log_error() {
  printf "[ERROR] %s\n" "$*" >&2
}

clear_screen() {
  if command -v tput >/dev/null 2>&1; then
    tput clear || printf "\033[2J\033[H"
  else
    printf "\033[2J\033[H"
  fi
}

fetch_sessions() {
  if ! command -v tmux >/dev/null 2>&1; then
    log_error "tmux is not available on PATH."
    return 1
  fi

  if ! tmux list-sessions >/dev/null 2>&1; then
    return 1
  fi

  tmux list-sessions -F '#S' 2>/dev/null
}

draw_menu() {
  local selected=$1
  shift
  local options=("$@")

  clear_screen
  printf "%s\n%s\n%s\n\n" "$BANNER_LINE" "$BANNER_TITLE" "$BANNER_LINE"
  printf "Use arrow keys to choose a session and press Enter to attach.\n"
  printf "Press 'q' to exit.\n\n"

  for idx in "${!options[@]}"; do
    if [[ $idx -eq $selected ]]; then
      printf "> %s\n" "${options[$idx]}"
    else
      printf "  %s\n" "${options[$idx]}"
    fi
  done
  printf "\n%s\n" "$BANNER_LINE"
}

interactive_select() {
  local options=("$@")
  local selected=0
  local key

  while true; do
    draw_menu "$selected" "${options[@]}"

    if ! read -rsn1 key; then
      continue
    fi

    case $key in
      $'\x1b')
        if ! read -rsn1 -t "$MENU_ARROW_TIMEOUT" key || [[ $key != "[" ]]; then
          continue
        fi
        if ! read -rsn1 -t "$MENU_ARROW_TIMEOUT" key; then
          continue
        fi
        case $key in
          A)
            selected=$(( (selected - 1 + ${#options[@]}) % ${#options[@]} ))
            ;;
          B)
            selected=$(( (selected + 1) % ${#options[@]} ))
            ;;
        esac
        ;;
      "")
        printf "%s\n" "${options[$selected]}"
        return 0
        ;;
      q|Q)
        return 1
        ;;
    esac
  done
}

collect_sessions() {
  local sessions=()
  while IFS= read -r session; do
    sessions+=("$session")
  done < <(fetch_sessions || true)

  printf '%s\0' "${sessions[@]}"
}

main() {
  local sessions=()
  local session_buffer
  session_buffer=$(collect_sessions)
  if [[ -n $session_buffer ]]; then
    while IFS= read -r -d '' entry; do
      sessions+=("$entry")
    done <<<"$session_buffer"
  fi

  if [[ ${#sessions[@]} -eq 0 ]]; then
    log_info "No tmux sessions available."
    exit 0
  fi

  sessions+=("Exit")

  if ! selection=$(interactive_select "${sessions[@]}"); then
    log_info "No session selected."
    exit 0
  fi

  if [[ $selection == "Exit" ]]; then
    log_info "Exiting without attaching."
    exit 0
  fi

  tmux attach-session -t "$selection"
}

main "$@"
