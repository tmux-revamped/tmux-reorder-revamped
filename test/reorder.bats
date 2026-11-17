#!/usr/bin/env bats
# shellcheck disable=SC2016,SC2030,SC2031,SC2034

# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

WINDOWS='REORDER_REVAMPED_WINDOWS=$(printf "%s\n" "1 @1 13" "2 @2 14" "3 @3 14" "4 @4 8"); '
LAYOUT='left|on|200|9|100|30|100|1'
HIT='#{?#{&&:#{e|>=:#{mouse_x},9},#{e|<:#{mouse_x},22}},@1,#{?#{&&:#{e|>=:#{mouse_x},23},#{e|<:#{mouse_x},37}},@2,#{?#{&&:#{e|>=:#{mouse_x},38},#{e|<:#{mouse_x},52}},@3,#{?#{&&:#{e|>=:#{mouse_x},53},#{e|<:#{mouse_x},61}},@4,}}}}'

setup() {
  harness_setup
  for name in $(compgen -v REORDER_REVAMPED_); do
    unset "${name}"
  done
}

option() {
  printf '%s' "$2" >"${REVAMPED_TEST_TMUX_DIR}/$(printf '%s' "g.-.@reorder_revamped_$1" | tr -c 'A-Za-z0-9_.-' '_')"
}

plan_at() {
  export REVAMPED_TEST_TMUX_VERSION="$1"
  lib_run reorder 'reorder_revamped_plan; reorder_revamped_lines'
}

hit_for() {
  lib_run reorder "${WINDOWS}"'reorder_revamped_hit "$PROBE_LAYOUT" "$REORDER_REVAMPED_WINDOWS"'
}

refuse() {
  mkdir -p "${BATS_TEST_TMPDIR}/stubs"
  printf '#!/bin/sh\nfor a in "$@"; do [ "$a" != ";" ] || exit 1; [ "$a" != BAD ] || { printf "unknown key: BAD\\n" >&2; exit 1; }; done\nexec "%s/bin/tmux" "$@"\n' "${REVAMPED_TESTS_DIR}" >"${BATS_TEST_TMPDIR}/stubs/tmux"
  chmod +x "${BATS_TEST_TMPDIR}/stubs/tmux"
}

@test "reorder - the version is read from tmux -V, next and patch builds included" {
  # Arrange
  local script='for v in "tmux 3.8" "tmux 3.5a" "tmux next-3.9" "tmux master"; do printf "[%s]" "$(reorder_revamped_parse_version "${v}")"; done'

  # Act
  lib_run reorder "${script}"

  # Assert
  [[ "${output}" == "[3.8][3.5][3.9][]" ]]
}

@test "reorder - version_ge compares major and minor numbers" {
  # Arrange
  local script='for p in "3.2 3.2" "3.10 3.2" "4.0 3.9" "3.1 3.2" "2.9 3.0" "x 3.2"; do set -- ${p}; if reorder_revamped_version_ge "$1" "$2"; then printf y; else printf n; fi; done'

  # Act
  lib_run reorder "${script}"

  # Assert
  [[ "${output}" == "yyynnn" ]]
}

@test "reorder - an unknown tmux version counts as new enough" {
  # Arrange
  local script='REORDER_REVAMPED_TMUX=""; reorder_revamped_at_least 9.9 && printf yes'

  # Act
  lib_run reorder "${script}"

  # Assert
  [[ "${output}" == "yes" ]]
}

@test "reorder - a drag is fresh only inside the timeout and with whole numbers" {
  # Arrange
  local script='for f in "1000 1005 10" "1000 1011 10" "1010 1000 10" "1000 soon 10" "1000 1005 x" "1000 1005 " " 1005 10"; do set -- ${f}; if reorder_revamped_is_fresh "${1:-}" "${2:-}" "${3:-}"; then printf y; else printf n; fi; done'

  # Act
  lib_run reorder "${script}"

  # Assert
  [[ "${output}" == "ynnnnnn" ]]
}

@test "reorder - an edge maps to the first or last position" {
  # Arrange
  local script='for e in "first 4 left" "last 4 left" "trailing 4 left" "trailing 4 centre" "middle 4 left"; do set -- ${e}; printf "[%s]" "$(reorder_revamped_edge_position "$1" "$2" "$3" || printf x)"; done'

  # Act
  lib_run reorder "${script}"

  # Assert
  [[ "${output}" == "[0][3][3][x][x]" ]]
}

@test "reorder - a path is quoted for run-shell with its quotes and hashes escaped" {
  # Arrange
  local script="reorder_revamped_quote_run_shell \"it's #1\""

  # Act
  lib_run reorder "${script}"

  # Assert
  [[ "${output}" == "'it'\\''s ##1'" ]]
}

@test "reorder - a command is escaped for a tmux double-quoted string" {
  # Arrange
  local script='reorder_revamped_quote_double "a\\b\"c\$d"'

  # Act
  lib_run reorder "${script}"

  # Assert
  [[ "${output}" == 'a\\b\"c\$d' ]]
}

@test "reorder - the tool path survives a quote in the checkout" {
  # Arrange
  export PROBE_LIB="/tmp/it's/lib"

  # Act
  lib_run reorder 'REVAMPED_LIB="${PROBE_LIB}"; reorder_revamped_tool'

  # Assert
  [[ "${output}" == "'/tmp/it'\\''s/bin/reorder-revamped'" ]]
}

@test "reorder - a window moved forward lands after the ones it passed" {
  # Arrange
  local script="${WINDOWS}"'reorder_revamped_moved 0 2 | awk "{ printf \"%s \", \$2 }"'

  # Act
  lib_run reorder "${script}"

  # Assert
  [[ "${output}" == "@2 @3 @1 @4 " ]]
}

@test "reorder - a window moved backward lands before the ones it passed" {
  # Arrange
  local script="${WINDOWS}"'reorder_revamped_moved 3 1 | awk "{ printf \"%s \", \$2 }"'

  # Act
  lib_run reorder "${script}"

  # Assert
  [[ "${output}" == "@1 @4 @2 @3 " ]]
}

@test "reorder - a window moved to the end is appended" {
  # Arrange
  local script="${WINDOWS}"'reorder_revamped_moved 0 3 | awk "{ printf \"%s \", \$2 }"'

  # Act
  lib_run reorder "${script}"

  # Assert
  [[ "${output}" == "@2 @3 @4 @1 " ]]
}

@test "reorder - the hit format maps each tab span after status-left to its window" {
  # Arrange
  export PROBE_LAYOUT="${LAYOUT}"

  # Act
  hit_for

  # Assert
  [[ "${output}" == "${HIT}" ]]
}

@test "reorder - the hit format caps status-left at its configured length" {
  # Arrange
  export PROBE_LAYOUT='left|on|200|120|100|30|100|1'

  # Act
  hit_for

  # Assert
  [[ "${output}" == *'#{e|>=:#{mouse_x},100},#{e|<:#{mouse_x},113}},@1,'* ]]
}

@test "reorder - the hit format maps nothing for a centred list, an overflow or two status lines" {
  # Arrange
  local script="${WINDOWS}"'for l in "centre|on|200|9|100|30|100|1" "left|on|60|9|100|30|100|1" "left|2|200|9|100|30|100|1"; do printf "[%s]" "$(reorder_revamped_hit "$l" "$REORDER_REVAMPED_WINDOWS")"; done; printf "[%s]" "$(reorder_revamped_hit "left|on|200|9|100|30|100|1" "")"'

  # Act
  lib_run reorder "${script}"

  # Assert
  [[ "${output}" == "[][][][]" ]]
}

@test "reorder - an insert walks the window through each neighbour by its real index" {
  # Arrange
  local script='REORDER_REVAMPED_WINDOWS=$(printf "%s\n" "1 @1 9" "3 @2 9" "5 @3 9"); reorder_revamped_swaps work @1 insert 0 2 | tr "\n" " "; printf "|"; reorder_revamped_swaps work @3 insert 2 0 | tr "\n" " "'

  # Act
  lib_run reorder "${script}"

  # Assert
  [[ "${output}" == "swap-window -d -s @1 -t work:3  swap-window -d -s @1 -t work:5  |swap-window -d -s @3 -t work:3  swap-window -d -s @3 -t work:1  " ]]
}

@test "reorder - a swap exchanges only the two windows" {
  # Arrange
  local script="${WINDOWS}"'reorder_revamped_swaps work @1 swap 0 2 | tr "\n" " "'

  # Act
  lib_run reorder "${script}"

  # Assert
  [[ "${output}" == "swap-window -d -s @1 -t work:3  " ]]
}

@test "reorder - tmux 3.8 measures the tabs when a drag starts and remeasures on each slide" {
  # Arrange
  local version=3.8

  # Act
  plan_at "${version}"

  # Assert
  [[ "${output}" == *"bind-key -n MouseDrag1Status if-shell -F "*"run-shell \"'"*"/bin/reorder-revamped' grab '#{session_id}' '#{client_name}'\" \\; set-option -gF @reorder_revamped_seen #{client_activity} \\; set-option -gF -t = @reorder_revamped_probe #{E:@reorder_revamped_hit}"*"'#{client_name}' 1\""* ]]
  [[ "${output}" != *"set-option -g @reorder_revamped_hit #{window_id}"* ]]
}

@test "reorder - tmux before 3.8 slides by the window under the pointer" {
  # Arrange
  local version=3.7

  # Act
  plan_at "${version}"

  # Assert
  [[ "${lines[0]}" == "set-option -g @reorder_revamped_hit #{window_id}" ]]
  [[ "${output}" == *"'#{client_name}' 0\""* ]]
  [[ "${output}" != *" grab "* ]]
}

@test "reorder - swap mode and live off bind no live slide" {
  # Arrange
  option mode swap
  export REVAMPED_TEST_TMUX_VERSION=3.8

  # Act
  lib_run reorder 'reorder_revamped_plan; reorder_revamped_lines | grep MouseDrag1Status; REORDER_REVAMPED_MODE=insert REORDER_REVAMPED_LIVE=off; export REORDER_REVAMPED_MODE REORDER_REVAMPED_LIVE; reorder_revamped_plan; reorder_revamped_lines | grep MouseDrag1Status'

  # Assert
  [[ "${#lines[@]}" -eq 2 ]]
  [[ "${lines[0]}" != *probe* ]]
  [[ "${lines[1]}" == "${lines[0]}" ]]
}

@test "reorder - the release drops on the tab and clears every drag option" {
  # Arrange
  local version=3.8

  # Act
  plan_at "${version}"

  # Assert
  [[ "${output}" == *"bind-key -n MouseDragEnd1Status run-shell -b -t = '"*"/bin/reorder-revamped' drop '#{session_id}' '#{@reorder_revamped_source}:#{@reorder_revamped_seen}' '#{window_id}' '#{client_activity}' \\; set-option -gu @reorder_revamped_source \\; set-option -gu @reorder_revamped_seen \\; set-option -gu @reorder_revamped_hover \\; set-option -gu @reorder_revamped_probe \\; set-option -gu @reorder_revamped_pressed \\; set-option -gu @reorder_revamped_pressed_at"* ]]
}

@test "reorder - the three edge drops are bound by default and skipped when edges are off" {
  # Arrange
  export REVAMPED_TEST_TMUX_VERSION=3.8

  # Act
  lib_run reorder 'reorder_revamped_plan; reorder_revamped_lines | grep -c "edge \(first\|last\|trailing\)"; REORDER_REVAMPED_EDGES=off; export REORDER_REVAMPED_EDGES; reorder_revamped_plan; reorder_revamped_lines | grep -c "MouseDragEnd1Status[LRD]" || :'

  # Assert
  [[ "${output}" == $'3\n0' ]]
}

@test "reorder - the press is recorded alone when nothing was bound to it" {
  # Arrange
  local version=3.8

  # Act
  plan_at "${version}"

  # Assert
  [[ "${lines[0]}" == "set-option -gu @reorder_revamped_press_original" ]]
  [[ "${lines[1]}" == "bind-key -n MouseDown1Status set-option -gF -t = @reorder_revamped_pressed #{window_id} \\; set-option -gF @reorder_revamped_pressed_at #{client_activity}" ]]
}

@test "reorder - nothing is bound below tmux 3.2" {
  # Arrange
  local version=3.1

  # Act
  plan_at "${version}"

  # Assert
  [[ -z "${output}" ]]
}

@test "reorder - apply sends every binding to tmux in one call" {
  # Arrange
  export REVAMPED_TEST_TMUX_VERSION=3.8 REVAMPED_TEST_TMUX_ARGV="${BATS_TEST_TMPDIR}/argv"

  # Act
  lib_run reorder reorder_revamped_apply

  # Assert
  run grep -c '^set-option|-gu|@reorder_revamped_press_original|;|bind-key|' "${REVAMPED_TEST_TMUX_ARGV}"
  [[ "${output}" == "1" ]]
  run grep -c '|;$' "${REVAMPED_TEST_TMUX_ARGV}"
  [[ "${output}" == "0" ]]
}

@test "reorder - apply calls tmux for nothing below 3.2" {
  # Arrange
  export REVAMPED_TEST_TMUX_VERSION=3.1 REVAMPED_TEST_TMUX_ARGV="${BATS_TEST_TMPDIR}/argv"

  # Act
  lib_run reorder reorder_revamped_apply

  # Assert
  [[ "${status}" -eq 0 ]]
  run grep -c 'bind-key' "${REVAMPED_TEST_TMUX_ARGV}"
  [[ "${output}" == "0" ]]
}

@test "reorder - a failed move is logged with the window and positions" {
  # Arrange
  mkdir -p "${BATS_TEST_TMPDIR}/stubs"
  printf '#!/bin/sh\n[ "$1" = swap-window ] && exit 1\nexec "%s/bin/tmux" "$@"\n' "${REVAMPED_TESTS_DIR}" >"${BATS_TEST_TMPDIR}/stubs/tmux"
  chmod +x "${BATS_TEST_TMPDIR}/stubs/tmux"
  option enable_logging 1
  export HOME="${BATS_TEST_TMPDIR}/home"

  # Act
  lib_run reorder "${WINDOWS}"'reorder_revamped_move work @1 insert 0 1'

  # Assert
  [[ "${status}" -eq 0 ]]
  run cat "${HOME}/.tmux/reorder-revamped-logs/reorder-revamped.log"
  [[ "${output}" == *"[reorder] moving @1 in work from position 0 to 1 failed" ]]
}

@test "reorder - a move ends on the dragged window and can carry the new hit format" {
  # Arrange
  export REVAMPED_TEST_TMUX_ARGV="${BATS_TEST_TMPDIR}/argv"

  # Act
  lib_run reorder "${WINDOWS}"'reorder_revamped_move work @1 insert 0 1 "#{x}"; reorder_revamped_move work @1 insert 0 1 ""'

  # Assert
  run cat "${REVAMPED_TEST_TMUX_ARGV}"
  [[ "${lines[0]}" == "swap-window|-d|-s|@1|-t|work:2|;|select-window|-t|@1|;|set-option|-g|@reorder_revamped_hit|#{x}" ]]
  [[ "${lines[1]}" == "swap-window|-d|-s|@1|-t|work:2|;|select-window|-t|@1|;|set-option|-gu|@reorder_revamped_hit" ]]
}

@test "reorder - json lists every command as its arguments" {
  # Arrange
  local script='REORDER_REVAMPED_PLAN="$(printf "a\\\\b\nsay \"hi\"\n\nnext\n")"; reorder_revamped_json'

  # Act
  lib_run reorder "${script}"

  # Assert
  [[ "${output}" == '{"bindings":[["a\\b","say \"hi\""],["next"]]}' ]]
}

@test "reorder - bindings counts the bind-key commands" {
  # Arrange
  export REVAMPED_TEST_TMUX_VERSION=3.8

  # Act
  lib_run reorder 'reorder_revamped_plan; reorder_revamped_bindings'

  # Assert
  [[ "${output}" == "9" ]]
}

@test "reorder - a setting name comes from its long option" {
  # Arrange
  local script='for o in --mode --timeout --colour; do printf "[%s]" "$(reorder_revamped_setting_name "$o")"; done'

  # Act
  lib_run reorder "${script}"

  # Assert
  [[ "${output}" == "[mode][timeout][]" ]]
}

@test "reorder - a setting comes from the environment, then the tmux option, then its default" {
  # Arrange
  option mode swap
  option timeout 4
  export REORDER_REVAMPED_TIMEOUT=7

  # Act
  lib_run reorder 'reorder_revamped_load; printf "[%s][%s][%s]" "${REORDER_REVAMPED_S_mode}" "${REORDER_REVAMPED_S_timeout}" "${REORDER_REVAMPED_S_live}"'

  # Assert
  [[ "${output}" == "[swap][7][on]" ]]
}

@test "reorder - the load also reads the justification and the saved press command" {
  # Arrange
  tmux_answer "$(printf '#{@reorder_revamped_mode}\t#{@reorder_revamped_live}\t#{@reorder_revamped_edges}\t#{@reorder_revamped_timeout}\t#{status-justify}\t#{@reorder_revamped_press_original}')" "$(printf '\t\t\t\tcentre\tselect-window -t =')" '$1'

  # Act
  lib_run reorder 'reorder_revamped_load "\$1"; printf "[%s][%s][%s]" "${REORDER_REVAMPED_S_justify}" "${REORDER_REVAMPED_S_press_original}" "${REORDER_REVAMPED_S_mode}"'

  # Assert
  [[ "${output}" == "[centre][select-window -t =][insert]" ]]
}

keys() {
  mkdir -p "${BATS_TEST_TMPDIR}/stubs"
  printf '%s\n' "$@" >"${BATS_TEST_TMPDIR}/keys"
  printf '#!/bin/sh\nif [ "$1" = list-keys ]; then cat "%s"; exit 0; fi\nexec "%s/bin/tmux" "$@"\n' "${BATS_TEST_TMPDIR}/keys" "${REVAMPED_TESTS_DIR}" >"${BATS_TEST_TMPDIR}/stubs/tmux"
  chmod +x "${BATS_TEST_TMPDIR}/stubs/tmux"
}

@test "reorder - the root press command is saved and kept running, whatever another table binds" {
  # Arrange
  keys 'bind-key    -T copy-mode MouseDown1Status select-pane' 'bind-key -r -T root      MouseDown1Status   select-window -t ='

  # Act
  plan_at 3.8

  # Assert
  [[ "${lines[0]}" == "set-option -g @reorder_revamped_press_original select-window -t =" ]]
  [[ "${lines[1]}" == *"\; if-shell -F 1 select-window -t =" ]]
}

@test "reorder - a second load reuses the saved press command instead of wrapping its wrapper" {
  # Arrange
  keys 'bind-key -T root MouseDown1Status set-option -gF -t = @reorder_revamped_pressed #{window_id}'
  option press_original 'switch-client -t ='

  # Act
  plan_at 3.8

  # Assert
  [[ "${lines[0]}" == "bind-key -n MouseDown1Status set-option -gF -t = @reorder_revamped_pressed #{window_id} \; set-option -gF @reorder_revamped_pressed_at #{client_activity} \; if-shell -F 1 switch-client -t =" ]]
}

@test "reorder - release and click bindings the person owns are left alone" {
  # Arrange
  keys 'bind-key -T root MouseUp1Status display-message up' 'bind-key -T root SecondClick1Status display-message twice'

  # Act
  plan_at 3.8

  # Assert
  [[ "${output}" != *"MouseUp1Status"* ]]
  [[ "${output}" != *"SecondClick1Status"* ]]
  [[ "${output}" == *"TripleClick1Status"* ]]
}

@test "reorder - edges off releases its own edge binding and keeps a foreign one" {
  # Arrange
  keys 'bind-key -T root MouseDragEnd1StatusLeft run-shell -b x \; set-option -gu @reorder_revamped_source' 'bind-key -T root MouseDragEnd1StatusRight display-message mine'
  option edges off

  # Act
  plan_at 3.8

  # Assert
  [[ "${output}" == *"unbind-key -n MouseDragEnd1StatusLeft"* ]]
  [[ "${output}" != *"MouseDragEnd1StatusRight"* ]]
}

@test "reorder - the layout is read for the client that dragged" {
  # Arrange
  local client=/dev/ttys009

  # Act
  lib_run reorder "reorder_revamped_layout work ${client}"

  # Assert
  run grep -c '^display-message -p -c /dev/ttys009 -t work ' "${REVAMPED_TEST_TMUX_LOG}"
  [[ "${output}" == "1" ]]
}

@test "reorder - each command is sent alone when the one call fails" {
  # Arrange
  refuse
  export REVAMPED_TEST_TMUX_VERSION=3.8
  export REVAMPED_TEST_TMUX_ARGV="${BATS_TEST_TMPDIR}/argv"

  # Act
  lib_run reorder reorder_revamped_apply

  # Assert
  [[ "${status}" -eq 0 ]]
  run grep -c '|;|' "${REVAMPED_TEST_TMUX_ARGV}"
  [[ "${output}" == "0" ]]
  run grep -c '^bind-key\|^set-option' "${REVAMPED_TEST_TMUX_ARGV}"
  [[ "${output}" -ge 2 ]]
}

@test "reorder - a mode and timeout from the command line or environment ride on the drop and edge bindings" {
  # Arrange
  export REVAMPED_TEST_TMUX_VERSION=3.8

  # Act
  lib_run reorder 'REORDER_REVAMPED_MODE=swap REORDER_REVAMPED_TIMEOUT=5; export REORDER_REVAMPED_MODE REORDER_REVAMPED_TIMEOUT; reorder_revamped_plan; reorder_revamped_lines | grep -E "MouseDragEnd1Status(Left)? "'

  # Assert
  [[ "${#lines[@]}" -eq 2 ]]
  [[ "${lines[0]}" == *"/bin/reorder-revamped' --mode 'swap' --timeout '5' drop '#{session_id}'"* ]]
  [[ "${lines[1]}" == *"/bin/reorder-revamped' --mode 'swap' --timeout '5' edge first '#{session_id}'"* ]]
}

@test "reorder - a mode from the tmux option stays live, so the drop binding carries none" {
  # Arrange
  option mode swap
  export REVAMPED_TEST_TMUX_VERSION=3.8

  # Act
  lib_run reorder 'reorder_revamped_plan; reorder_revamped_lines | grep -E "MouseDragEnd1Status "'

  # Assert
  [[ "${output}" == *"/bin/reorder-revamped' drop '#{session_id}'"* ]]
  [[ "${output}" != *"--mode"* ]]
}
