#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../helpers.bash"

setup() {
  setup_test_environment
  export REORDER_DRY_RUN=1
  source "${BATS_TEST_DIRNAME}/../../src/reorder.sh"
  MOCK_SETTINGS="||left"
  MOCK_WINDOWS=$'1 @1\n2 @2\n3 @3\n4 @4'
  MOCK_EDGES=""
  MOCK_VERSION="tmux 3.8"
  _query() { mock_query "$@"; }
  _tmux_version_string() { printf '%s\n' "${MOCK_VERSION}"; }
}

teardown() {
  cleanup_test_environment
}

mock_query() {
  case "${1}" in
    display-message) printf '%s\n' "${MOCK_SETTINGS}" ;;
    list-windows) printf '%s\n' "${MOCK_WINDOWS}" ;;
    show-option) printf '%s\n' "${MOCK_EDGES}" ;;
    list-keys) printf '%s\n' "${MOCK_KEYS:-}" ;;
  esac
}

@test "apply releases its own edge bindings when edges are turned off" {
  # Arrange
  MOCK_EDGES="off"
  MOCK_KEYS="bind-key -T root MouseDragEnd1StatusLeft run-shell -b \"bash '${REORDER_SELF}' edge first\""

  # Act
  run reorder_apply

  # Assert
  [[ "${lines[2]}" == "tmux unbind-key -n MouseDragEnd1StatusLeft" ]]
  [[ "${lines[3]}" == "tmux unbind-key -n MouseDragEnd1StatusRight" ]]
  [[ "${lines[4]}" == "tmux unbind-key -n MouseDragEnd1StatusDefault" ]]
}

@test "apply leaves an edge binding it does not own when edges are off" {
  # Arrange
  MOCK_EDGES="off"
  MOCK_KEYS="bind-key -T root MouseDragEnd1StatusLeft display-message mine"

  # Act
  run reorder_apply

  # Assert
  [[ "${output}" != *"unbind-key"* ]]
}

@test "drop falls back to the default timeout when the option is not a number" {
  # Arrange
  MOCK_SETTINGS="|soon|left"

  # Act
  run reorder_drop work "@1:1000" @2 1010

  # Assert
  [[ "${output}" == 'tmux swap-window -d -s @1 -t work:2 ; select-window -t @1' ]]
}

@test "apply records the grabbed window on every status drag" {
  # Arrange
  local expected="tmux bind-key -n MouseDrag1Status set-option -gF -t = @reorder_revamped_source #{window_id}:#{client_activity}"

  # Act
  run reorder_apply

  # Assert
  [[ "${lines[0]}" == "${expected}" ]]
}

@test "apply binds the drop on a tab to a quoted drop command" {
  # Arrange
  local self
  self="$(reorder_quote_for_run_shell "${REORDER_SELF}")"

  # Act
  run reorder_apply

  # Assert
  [[ "${lines[1]}" == "tmux bind-key -n MouseDragEnd1Status run-shell -b -t = bash ${self} drop '#{session_id}' '#{@reorder_revamped_source}' '#{window_id}' '#{client_activity}' \\; set-option -gu @reorder_revamped_source" ]]
}

@test "apply binds the three edge drops by default" {
  # Arrange
  MOCK_EDGES=""

  # Act
  run reorder_apply

  # Assert
  [[ "${#lines[@]}" -eq 5 ]]
  [[ "${lines[2]}" == *"MouseDragEnd1StatusLeft run-shell -b bash "*" edge first "* ]]
  [[ "${lines[3]}" == *"MouseDragEnd1StatusRight run-shell -b bash "*" edge last "* ]]
  [[ "${lines[4]}" == *"MouseDragEnd1StatusDefault run-shell -b bash "*" edge trailing "* ]]
}

@test "apply skips the edge drops when edges are off" {
  # Arrange
  MOCK_EDGES="off"

  # Act
  run reorder_apply

  # Assert
  [[ "${#lines[@]}" -eq 2 ]]
}

@test "apply binds nothing below tmux 3.2" {
  # Arrange
  MOCK_VERSION="tmux 3.1c"

  # Act
  run reorder_apply

  # Assert
  [[ "${status}" -eq 0 && -z "${output}" ]]
}

@test "drop forward walks the window through each neighbour" {
  # Arrange
  local source="@1:1000"

  # Act
  run reorder_drop work "${source}" @3 1000

  # Assert
  [[ "${output}" == 'tmux swap-window -d -s @1 -t work:2 ; swap-window -d -s @1 -t work:3 ; select-window -t @1' ]]
}

@test "drop backward walks the window toward the start" {
  # Arrange
  local source="@4:1000"

  # Act
  run reorder_drop work "${source}" @2 1000

  # Assert
  [[ "${output}" == 'tmux swap-window -d -s @4 -t work:3 ; swap-window -d -s @4 -t work:2 ; select-window -t @4' ]]
}

@test "drop keeps index gaps by targeting real indices" {
  # Arrange
  MOCK_WINDOWS=$'1 @1\n5 @2\n9 @3'

  # Act
  run reorder_drop work "@1:1000" @3 1000

  # Assert
  [[ "${output}" == 'tmux swap-window -d -s @1 -t work:5 ; swap-window -d -s @1 -t work:9 ; select-window -t @1' ]]
}

@test "drop in swap mode exchanges only the two windows" {
  # Arrange
  MOCK_SETTINGS="swap||left"

  # Act
  run reorder_drop work "@1:1000" @3 1000

  # Assert
  [[ "${output}" == 'tmux swap-window -d -s @1 -t work:3 ; select-window -t @1' ]]
}

@test "drop does nothing without a recorded source" {
  # Arrange
  local source=""

  # Act
  run reorder_drop work "${source}" @3 1000

  # Assert
  [[ "${status}" -eq 0 && -z "${output}" ]]
}

@test "drop does nothing when released on the grabbed tab" {
  # Arrange
  local source="@3:1000"

  # Act
  run reorder_drop work "${source}" @3 1000

  # Assert
  [[ "${status}" -eq 0 && -z "${output}" ]]
}

@test "drop ignores a source older than the default timeout" {
  # Arrange
  local source="@1:1000"

  # Act
  run reorder_drop work "${source}" @3 1011

  # Assert
  [[ "${status}" -eq 0 && -z "${output}" ]]
}

@test "drop honours a configured timeout" {
  # Arrange
  MOCK_SETTINGS="|30|left"

  # Act
  run reorder_drop work "@1:1000" @2 1025

  # Assert
  [[ "${output}" == 'tmux swap-window -d -s @1 -t work:2 ; select-window -t @1' ]]
}

@test "drop does nothing when the grabbed window has closed" {
  # Arrange
  MOCK_WINDOWS=$'2 @2\n3 @3'

  # Act
  run reorder_drop work "@1:1000" @3 1000

  # Assert
  [[ "${status}" -eq 0 && -z "${output}" ]]
}

@test "drop does nothing when the target window has closed" {
  # Arrange
  MOCK_WINDOWS=$'1 @1\n2 @2'

  # Act
  run reorder_drop work "@1:1000" @3 1000

  # Assert
  [[ "${status}" -eq 0 && -z "${output}" ]]
}

@test "edge first moves the window to the start" {
  # Arrange
  local source="@3:1000"

  # Act
  run reorder_edge first work "${source}" 1000

  # Assert
  [[ "${output}" == 'tmux swap-window -d -s @3 -t work:2 ; swap-window -d -s @3 -t work:1 ; select-window -t @3' ]]
}

@test "edge last moves the window to the end" {
  # Arrange
  local source="@2:1000"

  # Act
  run reorder_edge last work "${source}" 1000

  # Assert
  [[ "${output}" == 'tmux swap-window -d -s @2 -t work:3 ; swap-window -d -s @2 -t work:4 ; select-window -t @2' ]]
}

@test "edge trailing does nothing for a centred window list" {
  # Arrange
  MOCK_SETTINGS="||centre"

  # Act
  run reorder_edge trailing work "@2:1000" 1000

  # Assert
  [[ "${status}" -eq 0 && -z "${output}" ]]
}

@test "edge does nothing when the window is already at the edge" {
  # Arrange
  local source="@1:1000"

  # Act
  run reorder_edge first work "${source}" 1000

  # Assert
  [[ "${status}" -eq 0 && -z "${output}" ]]
}

@test "a failed move is logged with the window and positions" {
  # Arrange
  _tmux() { return 1; }
  log_error() { printf 'logged %s: %s\n' "${1}" "${2}"; }

  # Act
  run reorder_drop work "@1:1000" @2 1000

  # Assert
  [[ "${output}" == 'logged reorder: moving @1 in work from position 0 to 1 failed' ]]
}
