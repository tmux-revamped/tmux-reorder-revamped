#!/usr/bin/env bash

REORDER_PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REORDER_SELF="${REORDER_PLUGIN_DIR}/src/reorder.sh"
export PLUGIN_LOG_NS="reorder-revamped"

# shellcheck source=lib/reorder/plan.sh
source "${REORDER_PLUGIN_DIR}/src/lib/reorder/plan.sh"
# shellcheck source=lib/utils/error-logger.sh
source "${REORDER_PLUGIN_DIR}/src/lib/utils/error-logger.sh"

REORDER_WINDOW_INDICES=()
REORDER_WINDOW_IDS=()

_tmux() { [[ -n "${REORDER_DRY_RUN:-}" ]] && { printf 'tmux'; printf ' %s' "$@"; printf '\n'; return 0; }; command tmux "$@"; }

_query() { command tmux "$@"; }

_tmux_version_string() { command tmux -V 2>/dev/null; }

reorder_settings() {
  local separator="${REORDER_FIELD_SEPARATOR}"
  _query display-message -p -t "${1}" \
    "#{${REORDER_MODE_OPTION}}${separator}#{${REORDER_TIMEOUT_OPTION}}${separator}#{status-justify}"
}

reorder_load_windows() {
  local index id
  REORDER_WINDOW_INDICES=()
  REORDER_WINDOW_IDS=()
  while read -r index id; do
    [[ -n "${id}" ]] || continue
    REORDER_WINDOW_INDICES+=("${index}")
    REORDER_WINDOW_IDS+=("${id}")
  done < <(_query list-windows -t "${1}" -F '#{window_index} #{window_id}')
}

reorder_swap_chain() {
  local session="${1}" source_id="${2}" mode="${3}" from="${4}" to="${5}" position
  if [[ "${mode}" == "${REORDER_MODE_SWAP}" ]]; then
    printf '%s\n' swap-window -d -s "${source_id}" -t "${session}:${REORDER_WINDOW_INDICES[to]}" ';'
    return 0
  fi
  for position in $(reorder_path "${from}" "${to}"); do
    printf '%s\n' swap-window -d -s "${source_id}" -t "${session}:${REORDER_WINDOW_INDICES[position]}" ';'
  done
}

reorder_apply_moves() {
  local session="${1}" source_id="${2}" mode="${3}" from="${4}" to="${5}" word
  local commands=()
  while IFS= read -r word; do
    commands+=("${word}")
  done < <(reorder_swap_chain "${session}" "${source_id}" "${mode}" "${from}" "${to}")
  _tmux "${commands[@]}" select-window -t "${source_id}" ||
    log_error reorder "moving ${source_id} in ${session} from position ${from} to ${to} failed"
}

reorder_relocate() {
  local session="${1}" source="${2}" activity="${3}" edge="${4}" target_id="${5}"
  local source_id="${source%%:*}" recorded="${source#*:}" mode timeout justify from to
  [[ -n "${source_id}" && "${source_id}" != "${target_id}" ]] || return 0
  IFS="${REORDER_FIELD_SEPARATOR}" read -r mode timeout justify < <(reorder_settings "${session}")
  [[ "${timeout}" =~ ^[0-9]+$ ]] || timeout="${REORDER_DEFAULT_TIMEOUT}"
  reorder_is_fresh "${recorded}" "${activity}" "${timeout}" || return 0
  reorder_load_windows "${session}"
  from="$(reorder_position_of "${source_id}" "${REORDER_WINDOW_IDS[@]}")" || return 0
  if [[ -n "${target_id}" ]]; then
    to="$(reorder_position_of "${target_id}" "${REORDER_WINDOW_IDS[@]}")" || return 0
  else
    to="$(reorder_edge_position "${edge}" "${#REORDER_WINDOW_IDS[@]}" "${justify}")" || return 0
  fi
  ((from == to)) && return 0
  reorder_apply_moves "${session}" "${source_id}" "${mode:-${REORDER_MODE_INSERT}}" "${from}" "${to}"
}

reorder_drop() {
  reorder_relocate "${1}" "${2}" "${4}" "" "${3}"
}

reorder_edge() {
  reorder_relocate "${2}" "${3}" "${4}" "${1}" ""
}

reorder_bind_edge() {
  local key="${1}" edge="${2}" self="${3}"
  _tmux bind-key -n "${key}" run-shell -b \
    "bash ${self} edge ${edge} '#{session_id}' '#{${REORDER_SOURCE_OPTION}}' '#{client_activity}'" \
    '\;' set-option -gu "${REORDER_SOURCE_OPTION}"
}

reorder_release_edge() {
  local key="${1}"
  [[ "$(_query list-keys -T root "${key}" 2>/dev/null)" == *"${REORDER_SELF}"* ]] || return 0
  _tmux unbind-key -n "${key}"
}

reorder_apply_edges() {
  local self="${1}" edges
  edges="$(_query show-option -gqv "${REORDER_EDGES_OPTION}")"
  if [[ "${edges:-${REORDER_EDGES_ON}}" != "${REORDER_EDGES_ON}" ]]; then
    reorder_release_edge MouseDragEnd1StatusLeft
    reorder_release_edge MouseDragEnd1StatusRight
    reorder_release_edge MouseDragEnd1StatusDefault
    return 0
  fi
  reorder_bind_edge MouseDragEnd1StatusLeft "${REORDER_EDGE_FIRST}" "${self}"
  reorder_bind_edge MouseDragEnd1StatusRight "${REORDER_EDGE_LAST}" "${self}"
  reorder_bind_edge MouseDragEnd1StatusDefault "${REORDER_EDGE_TRAILING}" "${self}"
}

reorder_apply() {
  local version self
  version="$(reorder_parse_version "$(_tmux_version_string)")"
  reorder_version_supported "${version}" "${REORDER_MIN_TMUX}" || return 0
  self="$(reorder_quote_for_run_shell "${REORDER_SELF}")"
  _tmux bind-key -n MouseDrag1Status set-option -gF -t = "${REORDER_SOURCE_OPTION}" '#{window_id}:#{client_activity}'
  _tmux bind-key -n MouseDragEnd1Status run-shell -b -t = \
    "bash ${self} drop '#{session_id}' '#{${REORDER_SOURCE_OPTION}}' '#{window_id}' '#{client_activity}'" \
    '\;' set-option -gu "${REORDER_SOURCE_OPTION}"
  reorder_apply_edges "${self}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    drop) shift; reorder_drop "$@" ;;
    edge) shift; reorder_edge "$@" ;;
    *) reorder_apply ;;
  esac
fi
