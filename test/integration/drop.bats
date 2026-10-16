#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/reorder_helpers.bash"

setup() {
  start_reorder_server
  REORDER_SCRIPT="${PLUGIN_DIR}/src/reorder.sh"
  ACTIVITY=1792170000
}

teardown() {
  stop_reorder_server
}

@test "dropping the first window on the third inserts it there" {
  # Arrange
  local source target
  source="$(window_id_of "${WINDOW_NAMES[0]}"):${ACTIVITY}"
  target="$(window_id_of "${WINDOW_NAMES[2]}")"

  # Act
  bash "${REORDER_SCRIPT}" drop "$(test_session_id)" "${source}" "${target}" "${ACTIVITY}"

  # Assert
  [[ "$(window_order)" == "$(names_in_order 1 2 0 3)" ]]
}

@test "dropping the last window on the second inserts it there" {
  # Arrange
  local source target
  source="$(window_id_of "${WINDOW_NAMES[3]}"):${ACTIVITY}"
  target="$(window_id_of "${WINDOW_NAMES[1]}")"

  # Act
  bash "${REORDER_SCRIPT}" drop "$(test_session_id)" "${source}" "${target}" "${ACTIVITY}"

  # Assert
  [[ "$(window_order)" == "$(names_in_order 0 3 1 2)" ]]
}

@test "the dragged window is current after the drop" {
  # Arrange
  local source target
  source="$(window_id_of "${WINDOW_NAMES[0]}"):${ACTIVITY}"
  target="$(window_id_of "${WINDOW_NAMES[3]}")"

  # Act
  bash "${REORDER_SCRIPT}" drop "$(test_session_id)" "${source}" "${target}" "${ACTIVITY}"

  # Assert
  [[ "$(tmux display-message -p -t test '#{window_name}')" == "${WINDOW_NAMES[0]}" ]]
}

@test "swap mode exchanges the two windows on a real server" {
  # Arrange
  set_option @reorder_revamped_mode swap
  local source target
  source="$(window_id_of "${WINDOW_NAMES[0]}"):${ACTIVITY}"
  target="$(window_id_of "${WINDOW_NAMES[2]}")"

  # Act
  bash "${REORDER_SCRIPT}" drop "$(test_session_id)" "${source}" "${target}" "${ACTIVITY}"

  # Assert
  [[ "$(window_order)" == "$(names_in_order 2 1 0 3)" ]]
}

@test "the first edge moves a window to the start on a real server" {
  # Arrange
  local source
  source="$(window_id_of "${WINDOW_NAMES[2]}"):${ACTIVITY}"

  # Act
  bash "${REORDER_SCRIPT}" edge first "$(test_session_id)" "${source}" "${ACTIVITY}"

  # Assert
  [[ "$(window_order)" == "$(names_in_order 2 0 1 3)" ]]
}

@test "a stale source leaves the order untouched on a real server" {
  # Arrange
  local source target
  source="$(window_id_of "${WINDOW_NAMES[0]}"):$((ACTIVITY - 60))"
  target="$(window_id_of "${WINDOW_NAMES[2]}")"

  # Act
  bash "${REORDER_SCRIPT}" drop "$(test_session_id)" "${source}" "${target}" "${ACTIVITY}"

  # Assert
  [[ "$(window_order)" == "$(names_in_order 0 1 2 3)" ]]
}

@test "the entry point binds the drag and every drop" {
  # Arrange
  local entry="${PLUGIN_DIR}/reorder-revamped.tmux"

  # Act
  bash "${entry}"

  # Assert
  run tmux list-keys -T root
  [[ "${output}" == *"MouseDrag1Status"*"@reorder_revamped_source"* ]]
  [[ "${output}" == *"MouseDragEnd1Status "*" drop "* ]]
  [[ "${output}" == *"MouseDragEnd1StatusLeft"*" edge first "* ]]
  [[ "${output}" == *"MouseDragEnd1StatusRight"*" edge last "* ]]
  [[ "${output}" == *"MouseDragEnd1StatusDefault"*" edge trailing "* ]]
}
