#!/usr/bin/env bash

[[ -n "${_TMUX_REORDER_BINDINGS_LOADED:-}" ]] && return 0
_TMUX_REORDER_BINDINGS_LOADED=1

readonly REORDER_LIVE_NONE="none"
readonly REORDER_LIVE_COMPUTED="computed"
readonly REORDER_LIVE_WINDOW="window"

reorder_drop_arguments() {
  printf "'#{session_id}' '#{%s}:#{%s}'" "${REORDER_SOURCE_OPTION}" "${REORDER_SEEN_OPTION}"
}

reorder_bind_release() {
  local key="${1}" target_flag="${2}" action="${3}" option
  local command=(run-shell -b)
  [[ -n "${target_flag}" ]] && command+=(-t "=")
  command+=("${action}")
  for option in "${REORDER_SOURCE_OPTION}" "${REORDER_SEEN_OPTION}" "${REORDER_HOVER_OPTION}" \
    "${REORDER_PROBE_OPTION}" "${REORDER_PRESS_OPTION}" "${REORDER_PRESS_AT_OPTION}"; do
    command+=('\;' set-option -gu "${option}")
  done
  _tmux bind-key -n "${key}" "${command[@]}"
}

reorder_bind_edge() {
  local key="${1}" edge="${2}" self="${3}"
  reorder_bind_release "${key}" "" \
    "bash ${self} edge ${edge} $(reorder_drop_arguments) '#{client_activity}'"
}

reorder_release_edge() {
  local key="${1}"
  [[ "$(_query list-keys -T root "${key}" 2>/dev/null)" == *"${REORDER_SELF}"* ]] || return 0
  _tmux unbind-key -n "${key}"
}

reorder_apply_edges() {
  local self="${1}" edges
  edges="$(_query show-option -gqv "${REORDER_EDGES_OPTION}")"
  if [[ "${edges:-${REORDER_SWITCH_ON}}" != "${REORDER_SWITCH_ON}" ]]; then
    reorder_release_edge MouseDragEnd1StatusLeft
    reorder_release_edge MouseDragEnd1StatusRight
    reorder_release_edge MouseDragEnd1StatusDefault
    return 0
  fi
  reorder_bind_edge MouseDragEnd1StatusLeft "${REORDER_EDGE_FIRST}" "${self}"
  reorder_bind_edge MouseDragEnd1StatusRight "${REORDER_EDGE_LAST}" "${self}"
  reorder_bind_edge MouseDragEnd1StatusDefault "${REORDER_EDGE_TRAILING}" "${self}"
}

reorder_grab_commands() {
  local live="${1}" self="${2}" pressed="#{${REORDER_PRESS_OPTION}}"
  local record="set-option -gF ${REORDER_SOURCE_OPTION} '${pressed}' ; set-option -gF ${REORDER_HOVER_OPTION} '${pressed}'"
  local grab
  grab="$(reorder_quote_for_tmux_double "bash ${self} grab '#{session_id}' '#{client_name}'")"
  [[ "${live}" == "${REORDER_LIVE_COMPUTED}" ]] &&
    record="${record} ; run-shell \"${grab}\""
  printf '%s\n' "${record}"
}

reorder_slide_commands() {
  local live="${1}" self="${2}" recompute=0
  [[ "${live}" == "${REORDER_LIVE_COMPUTED}" ]] && recompute=1
  local slide
  slide="$(reorder_quote_for_tmux_double "bash ${self} slide '#{session_id}' '#{${REORDER_SOURCE_OPTION}}' '#{${REORDER_PROBE_OPTION}}' '#{client_name}' ${recompute}")"
  printf '%s\n' "set-option -gF ${REORDER_HOVER_OPTION} '#{${REORDER_PROBE_OPTION}}' ; run-shell \"${slide}\""
}

reorder_bind_grab() {
  local live="${1}" self="${2}"
  local source="${REORDER_SOURCE_OPTION}" seen="${REORDER_SEEN_OPTION}"
  local probe="${REORDER_PROBE_OPTION}" hover="${REORDER_HOVER_OPTION}"
  local fresh_press="#{e|<=:#{e|-:#{client_activity},#{${REORDER_PRESS_AT_OPTION}}},${REORDER_PRESS_WINDOW_SECONDS}}"
  local new_gesture="#{||:#{==:#{${source}},},#{e|>:#{e|-:#{client_activity},#{${seen}}},${REORDER_DRAG_GAP_SECONDS}}}"
  local new_drag="#{&&:#{${REORDER_PRESS_OPTION}},#{&&:${fresh_press},${new_gesture}}}"
  local command=(if-shell -F "${new_drag}" "$(reorder_grab_commands "${live}" "${self}")"
    '\;' set-option -gF "${seen}" '#{client_activity}')
  if [[ "${live}" != "${REORDER_LIVE_NONE}" ]]; then
    command+=('\;' set-option -gF -t "=" "${probe}" "#{E:${REORDER_HIT_OPTION}}"
      '\;' if-shell -F "#{&&:#{${probe}},#{!=:#{${probe}},#{${hover}}}}" "$(reorder_slide_commands "${live}" "${self}")")
  fi
  _tmux bind-key -n MouseDrag1Status "${command[@]}"
}

reorder_binding_command() {
  _query list-keys -T root "${1}" 2>/dev/null |
    sed -E "s/^bind-key[[:space:]]+(-[a-zA-Z][[:space:]]+)*-T[[:space:]]+root[[:space:]]+${1}[[:space:]]+//"
}

reorder_press_original() {
  local current
  current="$(reorder_binding_command MouseDown1Status)"
  if [[ "${current}" == *"${REORDER_PRESS_OPTION}"* ]]; then
    _query show-option -gqv "${REORDER_PRESS_ORIGINAL_OPTION}"
    return 0
  fi
  _tmux set-option -g "${REORDER_PRESS_ORIGINAL_OPTION}" "${current}" >/dev/null
  printf '%s\n' "${current}"
}

reorder_bind_press() {
  local original
  original="$(reorder_press_original)"
  local command=(set-option -gF -t "=" "${REORDER_PRESS_OPTION}" '#{window_id}'
    '\;' set-option -gF "${REORDER_PRESS_AT_OPTION}" '#{client_activity}')
  [[ -n "${original}" ]] && command+=('\;' if-shell -F 1 "${original}")
  _tmux bind-key -n MouseDown1Status "${command[@]}"
}

reorder_bind_repeat_press() {
  local key="${1}" current
  current="$(reorder_binding_command "${key}")"
  [[ -z "${current}" || "${current}" == *"${REORDER_PRESS_OPTION}"* ]] || return 0
  _tmux bind-key -n "${key}" set-option -gF -t "=" "${REORDER_PRESS_OPTION}" '#{window_id}' \
    '\;' set-option -gF "${REORDER_PRESS_AT_OPTION}" '#{client_activity}'
}

reorder_bind_press_release() {
  local current
  current="$(reorder_binding_command MouseUp1Status)"
  [[ -z "${current}" || "${current}" == *"${REORDER_PRESS_OPTION}"* ]] || return 0
  _tmux bind-key -n MouseUp1Status set-option -gu "${REORDER_PRESS_OPTION}" \
    '\;' set-option -gu "${REORDER_PRESS_AT_OPTION}"
}

reorder_live_strategy() {
  local version="${1}" mode live
  mode="$(_query show-option -gqv "${REORDER_MODE_OPTION}")"
  live="$(_query show-option -gqv "${REORDER_LIVE_OPTION}")"
  if [[ "${live:-${REORDER_SWITCH_ON}}" != "${REORDER_SWITCH_ON}" || "${mode}" == "${REORDER_MODE_SWAP}" ]]; then
    printf '%s\n' "${REORDER_LIVE_NONE}"
  elif reorder_version_supported "${version}" "${REORDER_LIVE_MIN_TMUX}"; then
    printf '%s\n' "${REORDER_LIVE_COMPUTED}"
  else
    printf '%s\n' "${REORDER_LIVE_WINDOW}"
  fi
}

reorder_apply() {
  local version self live
  version="$(reorder_parse_version "$(_tmux_version_string)")"
  reorder_version_supported "${version}" "${REORDER_MIN_TMUX}" || return 0
  self="$(reorder_quote_for_run_shell "${REORDER_SELF}")"
  live="$(reorder_live_strategy "${version}")"
  [[ "${live}" == "${REORDER_LIVE_WINDOW}" ]] &&
    _tmux set-option -g "${REORDER_HIT_OPTION}" "${REORDER_WINDOW_HIT_FORMAT}"
  reorder_bind_press
  reorder_bind_repeat_press SecondClick1Status
  reorder_bind_repeat_press TripleClick1Status
  reorder_bind_press_release
  reorder_bind_grab "${live}" "${self}"
  reorder_bind_release MouseDragEnd1Status "-t" \
    "bash ${self} drop $(reorder_drop_arguments) '#{window_id}' '#{client_activity}'"
  reorder_apply_edges "${self}"
}
