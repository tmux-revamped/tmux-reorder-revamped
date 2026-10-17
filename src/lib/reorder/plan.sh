#!/usr/bin/env bash

[[ -n "${_TMUX_REORDER_PLAN_LOADED:-}" ]] && return 0
_TMUX_REORDER_PLAN_LOADED=1

# shellcheck source=../utils/constants.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../utils" && pwd)/constants.sh"

reorder_parse_version() {
  printf '%s\n' "${1}" | sed -En 's/^tmux[ -]([a-z]+-)?([0-9]+)\.([0-9]+).*/\2 \3/p'
}

reorder_version_supported() {
  local have="${1}" want="${2}"
  [[ -z "${have}" ]] && return 0
  local have_major="${have% *}" have_minor="${have#* }"
  local want_major="${want%.*}" want_minor="${want#*.}"
  if ((have_major != want_major)); then
    ((have_major > want_major))
    return
  fi
  ((have_minor >= want_minor))
}

reorder_position_of() {
  local needle="${1}"
  shift
  local position=0 item
  for item in "$@"; do
    if [[ "${item}" == "${needle}" ]]; then
      printf '%s\n' "${position}"
      return 0
    fi
    position=$((position + 1))
  done
  return 1
}

reorder_path() {
  local from="${1}" to="${2}" step=1
  ((from > to)) && step=-1
  while ((from != to)); do
    from=$((from + step))
    printf '%s\n' "${from}"
  done
}

reorder_is_fresh() {
  local recorded="${1}" now="${2}" timeout="${3}"
  [[ "${recorded}" =~ ^[0-9]+$ && "${now}" =~ ^[0-9]+$ && "${timeout}" =~ ^[0-9]+$ ]] || return 1
  local age=$((now - recorded))
  ((age >= 0 && age <= timeout))
}

reorder_edge_position() {
  local edge="${1}" count="${2}" justify="${3}"
  case "${edge}" in
    "${REORDER_EDGE_FIRST}") printf '0\n' ;;
    "${REORDER_EDGE_LAST}") printf '%s\n' "$((count - 1))" ;;
    "${REORDER_EDGE_TRAILING}")
      [[ "${justify}" == "${REORDER_JUSTIFY_LEFT}" ]] || return 1
      printf '%s\n' "$((count - 1))"
      ;;
    *) return 1 ;;
  esac
}

reorder_moved_order() {
  local from="${1}" to="${2}"
  shift 2
  local items=("$@") position
  local moving="${items[from]}"
  local without=("${items[@]:0:from}" "${items[@]:from+1}")
  for ((position = 0; position < ${#without[@]}; position++)); do
    ((position == to)) && printf '%s\n' "${moving}"
    printf '%s\n' "${without[position]}"
  done
  ((to >= ${#without[@]})) && printf '%s\n' "${moving}"
  return 0
}

reorder_hit_format() {
  local start="${1}" separator="${2}"
  shift 2
  local expression="" closing="" entry id width end
  for entry in "$@"; do
    id="${entry%%:*}"
    width="${entry#*:}"
    end=$((start + width))
    expression="${expression}#{?#{&&:#{e|>=:#{mouse_x},${start}},#{e|<:#{mouse_x},${end}}},${id},"
    closing="${closing}}"
    start=$((end + separator))
  done
  printf '%s%s\n' "${expression}" "${closing}"
}

reorder_list_width() {
  local separator="${1}" total=0 count=0 entry
  shift
  for entry in "$@"; do
    total=$((total + ${entry#*:}))
    count=$((count + 1))
  done
  ((count > 1)) && total=$((total + separator * (count - 1)))
  printf '%s\n' "${total}"
}

reorder_quote_for_run_shell() {
  local quote="'" escaped="'\\''"
  local value="${1//"${quote}"/${escaped}}"
  printf "'%s'" "${value//#/##}"
}

reorder_quote_for_tmux_double() {
  local value="${1}" escaped="" character index
  for ((index = 0; index < ${#value}; index++)); do
    character="${value:index:1}"
    case "${character}" in
      '\' | '"' | '$') escaped="${escaped}\\${character}" ;;
      *) escaped="${escaped}${character}" ;;
    esac
  done
  printf '%s' "${escaped}"
}
