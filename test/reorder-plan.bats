#!/usr/bin/env bats
# shellcheck disable=SC2016,SC2030,SC2031,SC2034

# shellcheck source=test/reorder_helpers.bash
source "${BATS_TEST_DIRNAME:-.}/reorder_helpers.bash"

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
  [[ "${output}" == *"bind-key -n MouseDragEnd1Status run-shell -b -t = '"*"/bin/reorder-revamped' drop '#{session_id}' '#{@reorder_revamped_source}:#{@reorder_revamped_seen}' '#{window_id}' '#{client_activity}' '#{mouse_status_range}' \\; set-option -gu @reorder_revamped_source \\; set-option -gu @reorder_revamped_seen \\; set-option -gu @reorder_revamped_hover \\; set-option -gu @reorder_revamped_probe \\; set-option -gu @reorder_revamped_pressed \\; set-option -gu @reorder_revamped_pressed_at"* ]]
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
  tmux_answer "$(printf '#{@reorder_revamped_mode}\t#{@reorder_revamped_live}\t#{@reorder_revamped_edges}\t#{@reorder_revamped_timeout}\t#{@reorder_revamped_swipe}\t#{status-justify}\t#{@reorder_revamped_press_original}')" "$(printf '\t\t\t\t\tcentre\tselect-window -t =')" '$1'

  # Act
  lib_run reorder 'reorder_revamped_load "\$1"; printf "[%s][%s][%s]" "${REORDER_REVAMPED_S_justify}" "${REORDER_REVAMPED_S_press_original}" "${REORDER_REVAMPED_S_mode}"'

  # Assert
  [[ "${output}" == "[centre][select-window -t =][insert]" ]]
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
