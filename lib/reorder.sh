#!/bin/sh

[ -n "${REORDER_REVAMPED_REORDER_LOADED:-}" ] && return 0
REORDER_REVAMPED_REORDER_LOADED=1

# shellcheck source=SCRIPTDIR/state.sh
. "${REVAMPED_LIB:?}/state.sh"

reorder_revamped_format() {
  printf '%s\n' "${REORDER_REVAMPED_SETTINGS}" | awk -F '\t' '{ printf "%s#{@reorder_revamped_%s}", (NR > 1 ? "\t" : ""), $1 } END { printf "\t#{status-justify}\t#{@reorder_revamped_press_original}" }'
}

reorder_revamped_resolve() {
  env | REORDER_REVAMPED_ROWS="${REORDER_REVAMPED_SETTINGS}" REORDER_REVAMPED_LIVE="$1" awk '
    BEGIN {
      count = split(ENVIRON["REORDER_REVAMPED_ROWS"], rows, "\n")
      fields = split(ENVIRON["REORDER_REVAMPED_LIVE"], live, "\t")
      for (i = 1; i <= count; i++) {
        split(rows[i], field, "\t")
        name[i] = field[1]
        value[i] = (live[i] != "") ? live[i] : field[2]
        want["REORDER_REVAMPED_" toupper(field[1])] = i
      }
      original = live[count + 2]
      for (i = count + 3; i <= fields; i++) { original = original "\t" live[i] }
    }
    {
      at = index($0, "=")
      key = substr($0, 1, at - 1)
      if (key in want) { value[want[key]] = substr($0, at + 1) }
    }
    END {
      for (i = 1; i <= count; i++) { print name[i] "\t" value[i] }
      print "justify\t" live[count + 1]
      print "press_original\t" original
    }
  '
}

reorder_revamped_load() {
  reorder_revamped_load_format=$(reorder_revamped_format)
  if [ -n "${1:-}" ]; then
    set -- -t "$1"
  else
    set --
  fi
  reorder_revamped_load_live=$(tmux display-message -p "$@" "${reorder_revamped_load_format}" 2>/dev/null) || reorder_revamped_load_live=""
  reorder_revamped_load_values=$(reorder_revamped_resolve "${reorder_revamped_load_live}")
  while IFS='	' read -r reorder_revamped_load_name reorder_revamped_load_value; do
    IFS= read -r "REORDER_REVAMPED_S_${reorder_revamped_load_name}" <<EOF
${reorder_revamped_load_value}
EOF
  done <<EOF
${reorder_revamped_load_values}
EOF
}

reorder_revamped_parse_version() {
  printf '%s\n' "$1" | sed -En 's/^tmux[ -]([a-z]+-)?([0-9]+\.[0-9]+).*/\2/p'
}

reorder_revamped_version_ge() {
  case "$1:$2" in
  *[!0-9.:]* | :* | *:) return 1 ;;
  *) ;;
  esac
  reorder_revamped_version_ge_have="${1%%.*}"
  reorder_revamped_version_ge_want="${2%%.*}"
  [ "${reorder_revamped_version_ge_have}" -gt "${reorder_revamped_version_ge_want}" ] && return 0
  [ "${reorder_revamped_version_ge_have}" -eq "${reorder_revamped_version_ge_want}" ] || return 1
  reorder_revamped_version_ge_have="${1#*.}"
  reorder_revamped_version_ge_want="${2#*.}"
  [ "${reorder_revamped_version_ge_have%%.*}" -ge "${reorder_revamped_version_ge_want%%.*}" ]
}

reorder_revamped_at_least() {
  [ -z "${REORDER_REVAMPED_TMUX}" ] && return 0
  reorder_revamped_version_ge "${REORDER_REVAMPED_TMUX}" "$1"
}

reorder_revamped_emit() {
  for reorder_revamped_emit_arg in "$@"; do
    REORDER_REVAMPED_PLAN="${REORDER_REVAMPED_PLAN}${reorder_revamped_emit_arg}
"
  done
  REORDER_REVAMPED_PLAN="${REORDER_REVAMPED_PLAN}
"
}

reorder_revamped_send() {
  set --
  reorder_revamped_send_sep=""
  while IFS= read -r reorder_revamped_send_line; do
    if [ -z "${reorder_revamped_send_line}" ]; then
      [ "$#" -eq 0 ] || reorder_revamped_send_sep=";"
      continue
    fi
    [ -z "${reorder_revamped_send_sep}" ] || set -- "$@" "${reorder_revamped_send_sep}"
    reorder_revamped_send_sep=""
    set -- "$@" "${reorder_revamped_send_line}"
  done <<PLAN
${REORDER_REVAMPED_PLAN}
PLAN
  [ "$#" -gt 0 ] || return 0
  tmux "$@"
}

reorder_revamped_quote_run_shell() {
  printf '%s\n' "$1" | sed -e "s/'/'\\\\''/g" -e 's/#/##/g' -e "1s/^/'/" -e "\$s/\$/'/"
}

reorder_revamped_quote_double() {
  printf '%s\n' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\$/\\$/g'
}

reorder_revamped_tool() {
  reorder_revamped_quote_run_shell "${REVAMPED_LIB%/lib}/bin/reorder-revamped"
}

reorder_revamped_keys() {
  tmux list-keys 2>/dev/null | awk '
    {
      i = 2
      while (i <= NF && $i ~ /^-[A-Za-z]$/ && $i != "-T") { i++ }
      if ($i != "-T" || $(i + 1) != "root") { next }
      key = $(i + 2)
      line = $0
      for (j = 1; j <= i + 2; j++) { sub(/^[ \t]*[^ \t]+/, "", line) }
      sub(/^[ \t]+/, "", line)
      print key "\t" line
    }
  '
}

reorder_revamped_binding() {
  printf '%s\n' "${REORDER_REVAMPED_KEYS}" | awk -F '\t' -v key="$1" '$1 == key { sub(/^[^\t]*\t/, ""); print; exit }'
}

reorder_revamped_live_strategy() {
  if [ "${REORDER_REVAMPED_S_live}" != on ] || [ "${REORDER_REVAMPED_S_mode}" = swap ]; then
    printf 'none'
  elif reorder_revamped_at_least "${REORDER_REVAMPED_LIVE_MIN_TMUX}"; then
    printf 'computed'
  else
    printf 'window'
  fi
}

reorder_revamped_unset_drag() {
  for reorder_revamped_unset_drag_option in "${REORDER_REVAMPED_SOURCE}" "${REORDER_REVAMPED_SEEN}" "${REORDER_REVAMPED_HOVER}" "${REORDER_REVAMPED_PROBE}" "${REORDER_REVAMPED_PRESS}" "${REORDER_REVAMPED_PRESS_AT}"; do
    printf '%s\n' '\;' set-option -gu "${reorder_revamped_unset_drag_option}"
  done
}

reorder_revamped_emit_lines() {
  REORDER_REVAMPED_PLAN="${REORDER_REVAMPED_PLAN}$1

"
}

reorder_revamped_drop_arguments() {
  printf "'#{session_id}' '#{%s}:#{%s}'" "${REORDER_REVAMPED_SOURCE}" "${REORDER_REVAMPED_SEEN}"
}

reorder_revamped_plan_release() {
  reorder_revamped_plan_release_drag=$(reorder_revamped_unset_drag)
  reorder_revamped_plan_release_args=$(reorder_revamped_drop_arguments)
  reorder_revamped_emit_lines "bind-key
-n
MouseDragEnd1Status
run-shell
-b
-t
=
${REORDER_REVAMPED_SELF} drop ${reorder_revamped_plan_release_args} '#{window_id}' '#{client_activity}'
${reorder_revamped_plan_release_drag}"
}

reorder_revamped_plan_edges() {
  reorder_revamped_plan_edges_drag=$(reorder_revamped_unset_drag)
  reorder_revamped_plan_edges_args=$(reorder_revamped_drop_arguments)
  for reorder_revamped_plan_edges_pair in MouseDragEnd1StatusLeft:first MouseDragEnd1StatusRight:last MouseDragEnd1StatusDefault:trailing; do
    reorder_revamped_plan_edges_key="${reorder_revamped_plan_edges_pair%%:*}"
    if [ "${REORDER_REVAMPED_S_edges}" = on ]; then
      reorder_revamped_emit_lines "bind-key
-n
${reorder_revamped_plan_edges_key}
run-shell
-b
${REORDER_REVAMPED_SELF} edge ${reorder_revamped_plan_edges_pair#*:} ${reorder_revamped_plan_edges_args} '#{client_activity}'
${reorder_revamped_plan_edges_drag}"
      continue
    fi
    reorder_revamped_plan_edges_current=$(reorder_revamped_binding "${reorder_revamped_plan_edges_key}")
    case "${reorder_revamped_plan_edges_current}" in
    *"${REORDER_REVAMPED_SOURCE}"*) reorder_revamped_emit unbind-key -n "${reorder_revamped_plan_edges_key}" ;;
    *) : ;;
    esac
  done
}

reorder_revamped_plan_press() {
  reorder_revamped_plan_press_current=$(reorder_revamped_binding MouseDown1Status)
  case "${reorder_revamped_plan_press_current}" in
  *"${REORDER_REVAMPED_PRESS}"*) reorder_revamped_plan_press_original="${REORDER_REVAMPED_S_press_original}" ;;
  "")
    reorder_revamped_plan_press_original=""
    reorder_revamped_emit set-option -gu "${REORDER_REVAMPED_PRESS_ORIGINAL}"
    ;;
  *)
    reorder_revamped_plan_press_original="${reorder_revamped_plan_press_current}"
    reorder_revamped_emit set-option -g "${REORDER_REVAMPED_PRESS_ORIGINAL}" "${reorder_revamped_plan_press_current}"
    ;;
  esac
  set -- bind-key -n MouseDown1Status set-option -gF -t = "${REORDER_REVAMPED_PRESS}" '#{window_id}' '\;' set-option -gF "${REORDER_REVAMPED_PRESS_AT}" '#{client_activity}'
  [ -z "${reorder_revamped_plan_press_original}" ] || set -- "$@" '\;' if-shell -F 1 "${reorder_revamped_plan_press_original}"
  reorder_revamped_emit "$@"
}

reorder_revamped_plan_follow() {
  reorder_revamped_plan_follow_current=$(reorder_revamped_binding "$1")
  case "${reorder_revamped_plan_follow_current}" in
  "" | *"${REORDER_REVAMPED_PRESS}"*) : ;;
  *) return 0 ;;
  esac
  if [ "$1" = MouseUp1Status ]; then
    reorder_revamped_emit bind-key -n "$1" set-option -gu "${REORDER_REVAMPED_PRESS}" '\;' set-option -gu "${REORDER_REVAMPED_PRESS_AT}"
    return 0
  fi
  reorder_revamped_emit bind-key -n "$1" set-option -gF -t = "${REORDER_REVAMPED_PRESS}" '#{window_id}' '\;' set-option -gF "${REORDER_REVAMPED_PRESS_AT}" '#{client_activity}'
}

reorder_revamped_grab_commands() {
  reorder_revamped_grab_commands_pressed="#{${REORDER_REVAMPED_PRESS}}"
  printf "set-option -gF %s '%s' ; set-option -gF %s '%s'" "${REORDER_REVAMPED_SOURCE}" "${reorder_revamped_grab_commands_pressed}" "${REORDER_REVAMPED_HOVER}" "${reorder_revamped_grab_commands_pressed}"
  [ "$1" = computed ] || return 0
  reorder_revamped_grab_commands_run=$(reorder_revamped_quote_double "${REORDER_REVAMPED_SELF} grab '#{session_id}' '#{client_name}'")
  printf ' ; run-shell "%s"' "${reorder_revamped_grab_commands_run}"
}

reorder_revamped_slide_commands() {
  reorder_revamped_slide_commands_again=0
  [ "$1" != computed ] || reorder_revamped_slide_commands_again=1
  reorder_revamped_slide_commands_run=$(reorder_revamped_quote_double "${REORDER_REVAMPED_SELF} slide '#{session_id}' '#{${REORDER_REVAMPED_SOURCE}}' '#{${REORDER_REVAMPED_PROBE}}' '#{client_name}' ${reorder_revamped_slide_commands_again}")
  printf "set-option -gF %s '#{%s}' ; run-shell \"%s\"" "${REORDER_REVAMPED_HOVER}" "${REORDER_REVAMPED_PROBE}" "${reorder_revamped_slide_commands_run}"
}

reorder_revamped_plan_grab() {
  reorder_revamped_plan_grab_fresh="#{e|<=:#{e|-:#{client_activity},#{${REORDER_REVAMPED_PRESS_AT}}},${REORDER_REVAMPED_PRESS_WINDOW_SECONDS}}"
  reorder_revamped_plan_grab_new="#{||:#{==:#{${REORDER_REVAMPED_SOURCE}},},#{e|>:#{e|-:#{client_activity},#{${REORDER_REVAMPED_SEEN}}},${REORDER_REVAMPED_DRAG_GAP_SECONDS}}}"
  reorder_revamped_plan_grab_drag="#{&&:#{${REORDER_REVAMPED_PRESS}},#{&&:${reorder_revamped_plan_grab_fresh},${reorder_revamped_plan_grab_new}}}"
  reorder_revamped_plan_grab_record=$(reorder_revamped_grab_commands "$1")
  set -- "$1" bind-key -n MouseDrag1Status if-shell -F "${reorder_revamped_plan_grab_drag}" "${reorder_revamped_plan_grab_record}" '\;' set-option -gF "${REORDER_REVAMPED_SEEN}" '#{client_activity}'
  if [ "$1" != none ]; then
    reorder_revamped_plan_grab_slide=$(reorder_revamped_slide_commands "$1")
    set -- "$@" '\;' set-option -gF -t = "${REORDER_REVAMPED_PROBE}" "#{E:${REORDER_REVAMPED_HIT}}" '\;' if-shell -F "#{&&:#{${REORDER_REVAMPED_PROBE}},#{!=:#{${REORDER_REVAMPED_PROBE}},#{${REORDER_REVAMPED_HOVER}}}}" "${reorder_revamped_plan_grab_slide}"
  fi
  shift
  reorder_revamped_emit "$@"
}

reorder_revamped_plan() {
  reorder_revamped_load
  reorder_revamped_plan_raw=$(tmux -V 2>/dev/null) || reorder_revamped_plan_raw=""
  REORDER_REVAMPED_TMUX=$(reorder_revamped_parse_version "${reorder_revamped_plan_raw}")
  REORDER_REVAMPED_PLAN=""
  reorder_revamped_at_least "${REORDER_REVAMPED_MIN_TMUX}" || return 0
  REORDER_REVAMPED_KEYS=$(reorder_revamped_keys)
  REORDER_REVAMPED_SELF=$(reorder_revamped_tool)
  reorder_revamped_plan_live=$(reorder_revamped_live_strategy)
  [ "${reorder_revamped_plan_live}" != window ] || reorder_revamped_emit set-option -g "${REORDER_REVAMPED_HIT}" "${REORDER_REVAMPED_WINDOW_HIT_FORMAT}"
  reorder_revamped_plan_press
  reorder_revamped_plan_follow SecondClick1Status
  reorder_revamped_plan_follow TripleClick1Status
  reorder_revamped_plan_follow MouseUp1Status
  reorder_revamped_plan_grab "${reorder_revamped_plan_live}"
  reorder_revamped_plan_release
  reorder_revamped_plan_edges
}

reorder_revamped_apply() {
  reorder_revamped_plan
  reorder_revamped_send 2>/dev/null || reorder_revamped_apply_each
}

reorder_revamped_apply_each() {
  reorder_revamped_apply_each_status=0
  set --
  while IFS= read -r reorder_revamped_apply_each_line; do
    if [ -n "${reorder_revamped_apply_each_line}" ]; then
      set -- "$@" "${reorder_revamped_apply_each_line}"
      continue
    fi
    [ "$#" -gt 0 ] || continue
    tmux "$@" || reorder_revamped_apply_each_status=1
    set --
  done <<PLAN
${REORDER_REVAMPED_PLAN}
PLAN
  return "${reorder_revamped_apply_each_status}"
}

reorder_revamped_windows() {
  REORDER_REVAMPED_WINDOWS=$(tmux list-windows -t "$1" -F '#{window_index} #{window_id} #{?window_active,#{w:#{E:window-status-current-format}},#{w:#{E:window-status-format}}}' 2>/dev/null) || REORDER_REVAMPED_WINDOWS=""
}

reorder_revamped_position() {
  printf '%s\n' "${REORDER_REVAMPED_WINDOWS}" | awk -v id="$1" 'BEGIN { n = 0 } NF >= 2 { if ($2 == id) { print n; found = 1; exit } n++ } END { exit !found }'
}

reorder_revamped_count() {
  printf '%s\n' "${REORDER_REVAMPED_WINDOWS}" | awk 'NF >= 2 { n++ } END { print n + 0 }'
}

reorder_revamped_moved() {
  printf '%s\n' "${REORDER_REVAMPED_WINDOWS}" | awk -v from="$1" -v to="$2" '
    NF >= 2 { row[n++] = $0 }
    END {
      k = 0
      for (i = 0; i < n; i++) { if (i != from) { rest[k++] = row[i] } }
      for (i = 0; i < k; i++) {
        if (i == to) { print row[from] }
        print rest[i]
      }
      if (to >= k) { print row[from] }
    }
  '
}

reorder_revamped_layout() {
  if [ -n "${2:-}" ]; then
    set -- -c "$2" -t "$1"
  else
    set -- -t "$1"
  fi
  tmux display-message -p "$@" '#{status-justify}|#{status}|#{client_width}|#{w:#{E:status-left}}|#{status-left-length}|#{w:#{E:status-right}}|#{status-right-length}|#{w:#{E:window-status-separator}}' 2>/dev/null
}

reorder_revamped_hit() {
  printf '%s\n' "$2" | awk -v layout="$1" '
    BEGIN { n = 0 }
    NF >= 2 { id[n] = $2; width[n] = $3 + 0; n++ }
    END {
      split(layout, f, "|")
      if (f[1] != "left" || f[2] != "on" || n == 0) { exit }
      start = (f[4] + 0 < f[5] + 0) ? f[4] + 0 : f[5] + 0
      right = (f[6] + 0 < f[7] + 0) ? f[6] + 0 : f[7] + 0
      gap = f[8] + 0
      total = gap * (n - 1)
      for (i = 0; i < n; i++) { total += width[i] }
      if (start + total > f[3] - right) { exit }
      out = ""
      closing = ""
      for (i = 0; i < n; i++) {
        end = start + width[i]
        out = out "#{?#{&&:#{e|>=:#{mouse_x}," start "},#{e|<:#{mouse_x}," end "}}," id[i] ","
        closing = closing "}"
        start = end + gap
      }
      print out closing
    }
  '
}

reorder_revamped_swaps() {
  printf '%s\n' "${REORDER_REVAMPED_WINDOWS}" | awk -v session="$1" -v source="$2" -v mode="$3" -v from="$4" -v to="$5" '
    NF >= 2 { index_at[n++] = $1 }
    END {
      if (mode == "swap") { print "swap-window\n-d\n-s\n" source "\n-t\n" session ":" index_at[to] "\n"; exit }
      step = (from > to) ? -1 : 1
      for (at = from + step; ; at += step) {
        print "swap-window\n-d\n-s\n" source "\n-t\n" session ":" index_at[at] "\n"
        if (at == to) { break }
      }
    }
  '
}

reorder_revamped_move() {
  REORDER_REVAMPED_PLAN=$(reorder_revamped_swaps "$1" "$2" "$3" "$4" "$5")
  REORDER_REVAMPED_PLAN="${REORDER_REVAMPED_PLAN}

"
  reorder_revamped_emit select-window -t "$2"
  [ -z "${6:-}" ] || reorder_revamped_emit set-option -g "${REORDER_REVAMPED_HIT}" "$6"
  [ "${6-unset}" != "" ] || reorder_revamped_emit set-option -gu "${REORDER_REVAMPED_HIT}"
  reorder_revamped_send && return 0
  # shellcheck source=SCRIPTDIR/log.sh
  . "${REVAMPED_LIB}/log.sh"
  revamped_log_error reorder "moving $2 in $1 from position $4 to $5 failed"
}

reorder_revamped_grab() {
  reorder_revamped_windows "$1"
  reorder_revamped_grab_layout=$(reorder_revamped_layout "$1" "${2:-}")
  reorder_revamped_grab_hit=$(reorder_revamped_hit "${reorder_revamped_grab_layout}" "${REORDER_REVAMPED_WINDOWS}")
  tmux set-option -g "${REORDER_REVAMPED_HIT}" "${reorder_revamped_grab_hit}"
}

reorder_revamped_slide() {
  set -- "${1:-}" "${2:-}" "${3:-}" "${4:-}" "${5:-0}"
  [ -n "$2" ] && [ -n "$3" ] && [ "$2" != "$3" ] || return 0
  reorder_revamped_windows "$1"
  reorder_revamped_slide_from=$(reorder_revamped_position "$2") || return 0
  reorder_revamped_slide_to=$(reorder_revamped_position "$3") || return 0
  if [ "$5" != 1 ]; then
    reorder_revamped_move "$1" "$2" insert "${reorder_revamped_slide_from}" "${reorder_revamped_slide_to}"
    return 0
  fi
  reorder_revamped_slide_order=$(reorder_revamped_moved "${reorder_revamped_slide_from}" "${reorder_revamped_slide_to}")
  reorder_revamped_slide_layout=$(reorder_revamped_layout "$1" "$4")
  reorder_revamped_slide_hit=$(reorder_revamped_hit "${reorder_revamped_slide_layout}" "${reorder_revamped_slide_order}")
  reorder_revamped_move "$1" "$2" insert "${reorder_revamped_slide_from}" "${reorder_revamped_slide_to}" "${reorder_revamped_slide_hit}"
}

reorder_revamped_is_fresh() {
  case "$1:$2:$3" in
  *[!0-9:]* | :* | *::* | *:) return 1 ;;
  *) : ;;
  esac
  [ $(($2 - $1)) -ge 0 ] && [ $(($2 - $1)) -le "$3" ]
}

reorder_revamped_edge_position() {
  case "$1" in
  first) printf '0\n' ;;
  last) printf '%s\n' "$(($2 - 1))" ;;
  trailing)
    [ "$3" = left ] || return 1
    printf '%s\n' "$(($2 - 1))"
    ;;
  *) return 1 ;;
  esac
}

reorder_revamped_relocate() {
  set -- "$1" "$2" "$3" "$4" "$5" "${2%%:*}" "${2#*:}"
  [ -n "$6" ] && [ "$6" != "$5" ] || return 0
  reorder_revamped_load "$1"
  reorder_revamped_relocate_timeout="${REORDER_REVAMPED_S_timeout}"
  case "${reorder_revamped_relocate_timeout}" in
  "" | *[!0-9]*) reorder_revamped_relocate_timeout="${REORDER_REVAMPED_DEFAULT_TIMEOUT}" ;;
  *) : ;;
  esac
  reorder_revamped_is_fresh "$7" "$3" "${reorder_revamped_relocate_timeout}" || return 0
  reorder_revamped_windows "$1"
  reorder_revamped_relocate_from=$(reorder_revamped_position "$6") || return 0
  if [ -n "$5" ]; then
    reorder_revamped_relocate_to=$(reorder_revamped_position "$5") || return 0
  else
    reorder_revamped_relocate_count=$(reorder_revamped_count)
    reorder_revamped_relocate_to=$(reorder_revamped_edge_position "$4" "${reorder_revamped_relocate_count}" "${REORDER_REVAMPED_S_justify}") || return 0
  fi
  [ "${reorder_revamped_relocate_from}" != "${reorder_revamped_relocate_to}" ] || return 0
  reorder_revamped_relocate_mode=insert
  [ "${REORDER_REVAMPED_S_mode}" != swap ] || reorder_revamped_relocate_mode=swap
  reorder_revamped_move "$1" "$6" "${reorder_revamped_relocate_mode}" "${reorder_revamped_relocate_from}" "${reorder_revamped_relocate_to}"
}

reorder_revamped_drop() {
  reorder_revamped_relocate "${1:-}" "${2:-}" "${4:-}" "" "${3:-}"
}

reorder_revamped_edge() {
  reorder_revamped_relocate "${2:-}" "${3:-}" "${4:-}" "${1:-}" ""
}

reorder_revamped_lines() {
  printf '%s' "${REORDER_REVAMPED_PLAN}" | awk 'NF == 0 && line != "" { print line; line = ""; next } NF == 0 { next } { line = (line == "" ? $0 : line " " $0) } END { if (line != "") { print line } }'
}

reorder_revamped_json() {
  printf '%s' "${REORDER_REVAMPED_PLAN}" | awk '
    function quote(s,    out, i, c) {
      out = ""
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c == "\\") { out = out "\\\\" } else if (c == "\"") { out = out "\\\"" } else { out = out c }
      }
      return "\"" out "\""
    }
    /^$/ { if (args != "") { rows = rows (rows == "" ? "" : ",") "[" args "]" } args = ""; next }
    { args = args (args == "" ? "" : ",") quote($0) }
    END {
      if (args != "") { rows = rows (rows == "" ? "" : ",") "[" args "]" }
      print "{\"bindings\":[" rows "]}"
    }
  '
}

reorder_revamped_bindings() {
  printf '%s' "${REORDER_REVAMPED_PLAN}" | awk 'previous == "" && $0 == "bind-key" { count++ } { previous = $0 } END { print count + 0 }'
}

reorder_revamped_setting_name() {
  reorder_revamped_setting_name_raw=$(printf '%s\n' "${1#--}" | tr '-' '_')
  case " ${REORDER_REVAMPED_NAMES} " in
  *" ${reorder_revamped_setting_name_raw} "*) printf '%s\n' "${reorder_revamped_setting_name_raw}" ;;
  *) printf '\n' ;;
  esac
}
