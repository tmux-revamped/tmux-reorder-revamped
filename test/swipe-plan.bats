#!/usr/bin/env bats
# shellcheck disable=SC2016,SC2030,SC2031,SC2034

# shellcheck source=test/reorder_helpers.bash
source "${BATS_TEST_DIRNAME:-.}/reorder_helpers.bash"

swipe_lines() {
  grep -e 3Pane -e swipe_original <<<"${output}"
}

tmux_log() {
  export REVAMPED_TEST_TMUX_LOG="${BATS_TEST_TMPDIR}/tmux.log"
  : >"${REVAMPED_TEST_TMUX_LOG}"
}

@test "swipe - off by default, the plan binds nothing on the right button" {
  # Arrange
  keys 'bind-key -T root MouseDown3Pane display-menu -t = stock'

  # Act
  plan_at 3.8

  # Assert
  [[ "${output}" != *3Pane* ]]
}

@test "swipe - on, the press passes to apps and modes, and the command bound before moves to the release" {
  # Arrange
  option swipe on
  keys 'bind-key -T root MouseDown3Pane display-menu -t = stock'

  # Act
  plan_at 3.8

  # Assert
  run swipe_lines
  [[ "${lines[0]}" == "set-option -g @reorder_revamped_swipe_original display-menu -t = stock" ]] || false
  [[ "${lines[1]}" == "bind-key -n MouseDown3Pane set-option -gu @reorder_revamped_swipe_from \; if-shell -F -t = #{||:#{mouse_any_flag},#{pane_in_mode}} select-pane -t = ; send-keys -M" ]] || false
  [[ "${lines[2]}" == "bind-key -n MouseUp3Pane set-option -gu @reorder_revamped_swipe_from \; if-shell -F 1 display-menu -t = stock" ]]
}

@test "swipe - on, the first motion records where the drag began and the release runs the swipe" {
  # Arrange
  option swipe on

  # Act
  plan_at 3.8

  # Assert
  run swipe_lines
  [[ "${lines[1]}" == "bind-key -n MouseUp3Pane set-option -gu @reorder_revamped_swipe_from \; if-shell -F -t = #{mouse_any_flag} send-keys -M" ]] || false
  [[ "${lines[2]}" == "bind-key -n MouseDrag3Pane if-shell -F -t = #{mouse_any_flag} send-keys -M \; if-shell -F -t = #{&&:#{!:#{mouse_any_flag}},#{==:#{@reorder_revamped_swipe_from},}} set-option -gF @reorder_revamped_swipe_from '#{mouse_x} #{mouse_y}'" ]] || false
  [[ "${lines[3]}" == "bind-key -n MouseDragEnd3Pane if-shell -F -t = #{mouse_any_flag} send-keys -M run-shell -b \"'"*"/bin/reorder-revamped' swipe '#{@reorder_revamped_swipe_from}' '#{mouse_x} #{mouse_y}' '#{session_id}' '#{client_name}'\" ; set-option -gu @reorder_revamped_swipe_from" ]] || false
  [[ "${#lines[@]}" -eq 4 ]]
}

@test "swipe - a second load reuses the saved command instead of wrapping its own binding" {
  # Arrange
  option swipe on
  option swipe_original 'display-menu -t = stock'
  keys 'bind-key -T root MouseDown3Pane set-option -gu @reorder_revamped_swipe_from \; if-shell -F -t = "#{mouse_any_flag}" "send-keys -M"'

  # Act
  plan_at 3.8

  # Assert
  run swipe_lines
  [[ "${lines[0]}" == "set-option -g @reorder_revamped_swipe_original display-menu -t = stock" ]] || false
  [[ "${lines[2]}" == "bind-key -n MouseUp3Pane set-option -gu @reorder_revamped_swipe_from \; if-shell -F 1 display-menu -t = stock" ]]
}

@test "swipe - turned off, the saved command goes back on the press and the rest is unbound" {
  # Arrange
  option swipe_original 'display-menu -t = stock'
  keys 'bind-key -T root MouseDown3Pane set-option -gu @reorder_revamped_swipe_from \; if-shell -F -t = "#{mouse_any_flag}" "send-keys -M"'

  # Act
  plan_at 3.8

  # Assert
  run swipe_lines
  [[ "${output}" == "bind-key -n MouseDown3Pane display-menu -t = stock"$'\n'"unbind-key -n MouseUp3Pane"$'\n'"unbind-key -n MouseDrag3Pane"$'\n'"unbind-key -n MouseDragEnd3Pane"$'\n'"set-option -gu @reorder_revamped_swipe_original" ]]
}

@test "swipe - turned off with nothing saved, the press is unbound too" {
  # Arrange
  keys 'bind-key -T root MouseDown3Pane set-option -gu @reorder_revamped_swipe_from \; if-shell -F -t = "#{mouse_any_flag}" "send-keys -M"'

  # Act
  plan_at 3.8

  # Assert
  run swipe_lines
  [[ "${lines[0]}" == "unbind-key -n MouseDown3Pane" ]]
}

@test "swipe - the longer side of the drag decides between window and session, and its sign the direction" {
  # Arrange
  local script='for pair in "10 5|20 5" "20 5|10 6" "10 5|11 9" "10 9|10 2" "10 5|10 5" "10 5|13 8" "x 5|1 2" "|" "1 2 3|4 5" "1|2 3"; do printf "[%s]" "$(reorder_revamped_swipe_way "${pair%%|*}" "${pair#*|}")"; done'

  # Act
  lib_run reorder "${script}"

  # Assert
  [[ "${output}" == "[next-window][previous-window][next-session][previous-session][][][][][][]" ]]
}

@test "swipe - a sideways swipe changes window in the session it happened in" {
  # Arrange
  tmux_log

  # Act
  lib_run reorder 'reorder_revamped_swipe "10 5" "30 5" "\$3" /dev/ttys001; reorder_revamped_swipe "30 5" "10 5" "\$3" /dev/ttys001'

  # Assert
  run cat "${REVAMPED_TEST_TMUX_LOG}"
  [[ "${output}" == 'next-window -t $3'$'\n''previous-window -t $3' ]]
}

@test "swipe - an up or down swipe changes session for the client that swiped, and a short one does nothing" {
  # Arrange
  tmux_log

  # Act
  lib_run reorder 'reorder_revamped_swipe "10 5" "10 9" "\$3" /dev/ttys001; reorder_revamped_swipe "10 9" "10 5" "\$3" /dev/ttys001; reorder_revamped_swipe "10 5" "10 5" "\$3" /dev/ttys001'

  # Assert
  run cat "${REVAMPED_TEST_TMUX_LOG}"
  [[ "${output}" == 'switch-client -c /dev/ttys001 -n'$'\n''switch-client -c /dev/ttys001 -p' ]]
}

@test "session - a tab dropped on a session goes there when it is not one of its windows" {
  # Arrange
  mkdir -p "${BATS_TEST_TMPDIR}/stubs"
  printf '#!/bin/sh\nif [ "$1" = list-windows ]; then printf "%%s\\n" "0 @7 5" "1 @8 5"; exit 0; fi\nexec "%s/bin/tmux" "$@"\n' "${REVAMPED_TESTS_DIR}" >"${BATS_TEST_TMPDIR}/stubs/tmux"
  chmod +x "${BATS_TEST_TMPDIR}/stubs/tmux"
  tmux_log

  # Act
  lib_run reorder 'reorder_revamped_drop "\$2" "@1:100" "@7" 103 session'

  # Assert
  run grep move-window "${REVAMPED_TEST_TMUX_LOG}"
  [[ "${output}" == 'move-window -d -s @1 -t $2:' ]]
}

@test "session - a drop on a session moves nothing when the window is already there, the drag is stale or no tab was dragged" {
  # Arrange
  mkdir -p "${BATS_TEST_TMPDIR}/stubs"
  printf '#!/bin/sh\nif [ "$1" = list-windows ]; then printf "%%s\\n" "0 @7 5" "1 @8 5"; exit 0; fi\nexec "%s/bin/tmux" "$@"\n' "${REVAMPED_TESTS_DIR}" >"${BATS_TEST_TMPDIR}/stubs/tmux"
  chmod +x "${BATS_TEST_TMPDIR}/stubs/tmux"
  tmux_log

  # Act
  lib_run reorder 'reorder_revamped_drop "\$2" "@8:100" "@7" 103 session; reorder_revamped_drop "\$2" "@1:100" "@7" 500 session; reorder_revamped_drop "\$2" ":" "@7" 103 session'

  # Assert
  [[ "${status}" -eq 0 ]]
  run grep -c move-window "${REVAMPED_TEST_TMUX_LOG}"
  [[ "${output}" == "0" ]]
}

@test "session - a failed move to a session is logged" {
  # Arrange
  mkdir -p "${BATS_TEST_TMPDIR}/stubs"
  printf '#!/bin/sh\n[ "$1" = move-window ] && exit 1\nexec "%s/bin/tmux" "$@"\n' "${REVAMPED_TESTS_DIR}" >"${BATS_TEST_TMPDIR}/stubs/tmux"
  chmod +x "${BATS_TEST_TMPDIR}/stubs/tmux"
  option enable_logging 1
  export HOME="${BATS_TEST_TMPDIR}/home"

  # Act
  lib_run reorder 'reorder_revamped_drop "\$2" "@1:100" "@7" 103 session'

  # Assert
  [[ "${status}" -eq 0 ]]
  run cat "${HOME}/.tmux/reorder-revamped-logs/reorder-revamped.log"
  [[ "${output}" == *'[reorder] moving @1 to session $2 failed' ]]
}
