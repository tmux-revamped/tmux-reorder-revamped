#!/usr/bin/env bash

REORDER_PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REORDER_SELF="${REORDER_PLUGIN_DIR}/src/reorder.sh"
export PLUGIN_LOG_NS="reorder-revamped"

# shellcheck source=lib/reorder/plan.sh
source "${REORDER_PLUGIN_DIR}/src/lib/reorder/plan.sh"
# shellcheck source=lib/utils/error-logger.sh
source "${REORDER_PLUGIN_DIR}/src/lib/utils/error-logger.sh"

REORDER_WINDOW_INDICES=()
REORDER_WINDOW_IDS=()
REORDER_WINDOW_SPANS=()

_tmux() { [[ -n "${REORDER_DRY_RUN:-}" ]] && { printf 'tmux'; printf ' %s' "$@"; printf '\n'; return 0; }; command tmux "$@"; }

_query() { command tmux "$@"; }

_tmux_version_string() { command tmux -V 2>/dev/null; }

reorder_settings() {
  local separator="${REORDER_FIELD_SEPARATOR}"
  _query display-message -p -t "${1}" \
    "#{${REORDER_MODE_OPTION}}${separator}#{${REORDER_TIMEOUT_OPTION}}${separator}#{status-justify}"
}

reorder_layout() {
  local session="${1}" client="${2}" separator="${REORDER_FIELD_SEPARATOR}"
  local client_flag=()
  [[ -n "${client}" ]] && client_flag=(-c "${client}")
  _query display-message -p "${client_flag[@]}" -t "${session}" \
    "#{status-justify}${separator}#{status}${separator}#{client_width}${separator}#{w:#{E:status-left}}${separator}#{status-left-length}${separator}#{w:#{E:status-right}}${separator}#{status-right-length}${separator}#{w:#{E:window-status-separator}}"
}

reorder_load_windows() {
  local index id width
  REORDER_WINDOW_INDICES=()
  REORDER_WINDOW_IDS=()
  REORDER_WINDOW_SPANS=()
  while read -r index id width; do
    [[ -n "${id}" ]] || continue
    REORDER_WINDOW_INDICES+=("${index}")
    REORDER_WINDOW_IDS+=("${id}")
    REORDER_WINDOW_SPANS+=("${id}:${width:-0}")
  done < <(_query list-windows -t "${1}" -F \
    '#{window_index} #{window_id} #{?window_active,#{w:#{E:window-status-current-format}},#{w:#{E:window-status-format}}}')
}

reorder_span_of() {
  local id="${1}" span
  for span in "${REORDER_WINDOW_SPANS[@]}"; do
    [[ "${span%%:*}" == "${id}" ]] && { printf '%s\n' "${span}"; return 0; }
  done
  return 1
}

reorder_hit_for_order() {
  local session="${1}" client="${2}"
  shift 2
  local justify lines width left left_max right right_max separator id spans=() start total
  IFS="${REORDER_FIELD_SEPARATOR}" read -r justify lines width left left_max right right_max separator \
    < <(reorder_layout "${session}" "${client}")
  [[ "${justify}" == "${REORDER_JUSTIFY_LEFT}" && "${lines}" == "${REORDER_STATUS_SINGLE_LINE}" ]] || return 0
  for id in "$@"; do
    spans+=("$(reorder_span_of "${id}")")
  done
  start=$((left < left_max ? left : left_max))
  right=$((right < right_max ? right : right_max))
  total="$(reorder_list_width "${separator}" "${spans[@]}")"
  ((start + total <= width - right)) || return 0
  reorder_hit_format "${start}" "${separator}" "${spans[@]}"
}

reorder_grab() {
  local session="${1}" client="${2}" hit
  reorder_load_windows "${session}"
  hit="$(reorder_hit_for_order "${session}" "${client}" "${REORDER_WINDOW_IDS[@]}")"
  _tmux set-option -g "${REORDER_HIT_OPTION}" "${hit}"
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
  shift 5
  local commands=()
  while IFS= read -r word; do
    commands+=("${word}")
  done < <(reorder_swap_chain "${session}" "${source_id}" "${mode}" "${from}" "${to}")
  _tmux "${commands[@]}" select-window -t "${source_id}" "$@" ||
    log_error reorder "moving ${source_id} in ${session} from position ${from} to ${to} failed"
}

reorder_slide() {
  local session="${1}" source_id="${2}" target_id="${3}" client="${4}" recompute="${5:-0}" from to hit id
  local order=()
  [[ -n "${source_id}" && -n "${target_id}" && "${source_id}" != "${target_id}" ]] || return 0
  reorder_load_windows "${session}"
  from="$(reorder_position_of "${source_id}" "${REORDER_WINDOW_IDS[@]}")" || return 0
  to="$(reorder_position_of "${target_id}" "${REORDER_WINDOW_IDS[@]}")" || return 0
  if [[ "${recompute}" != "1" ]]; then
    reorder_apply_moves "${session}" "${source_id}" "${REORDER_MODE_INSERT}" "${from}" "${to}"
    return 0
  fi
  while IFS= read -r id; do
    order+=("${id}")
  done < <(reorder_moved_order "${from}" "${to}" "${REORDER_WINDOW_IDS[@]}")
  hit="$(reorder_hit_for_order "${session}" "${client}" "${order[@]}")"
  reorder_apply_moves "${session}" "${source_id}" "${REORDER_MODE_INSERT}" "${from}" "${to}" \
    ';' set-option -g "${REORDER_HIT_OPTION}" "${hit}"
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

# shellcheck source=lib/reorder/bindings.sh
source "${REORDER_PLUGIN_DIR}/src/lib/reorder/bindings.sh"

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    drop) shift; reorder_drop "$@" ;;
    edge) shift; reorder_edge "$@" ;;
    grab) shift; reorder_grab "$@" ;;
    slide) shift; reorder_slide "$@" ;;
    *) reorder_apply ;;
  esac
fi
