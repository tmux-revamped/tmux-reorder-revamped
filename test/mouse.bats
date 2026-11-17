#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031,SC2034,SC2154

# shellcheck source=test/mouse_helpers.bash
source "${BATS_TEST_DIRNAME:-.}/mouse_helpers.bash"

bats_require_minimum_version 1.5.0

@test "mouse - dragging a tab onto another tab reorders the windows" {
  # Arrange
  local from to
  from=$(column_of ":a")
  to=$(column_of ":c")

  # Act
  drag "${from}" "${to}"

  # Assert
  wait_for order_is "b c a d"
}

@test "mouse - dragging a tab onto empty status space moves it to the end" {
  # Arrange
  local from
  from=$(column_of ":b")

  # Act
  drag "${from}" $((COLUMNS / 2))

  # Assert
  wait_for order_is "a c d b"
}

@test "mouse - a text drag from a pane that ends on a tab moves nothing" {
  # Arrange
  local tab from to
  tab=$(column_of ":b")
  send_mouse 0 "${tab}" 5 M
  send_mouse 32 "${tab}" $((ROWS - 1)) M
  send_mouse 32 "${tab}" "${ROWS}" M
  send_mouse 0 "${tab}" "${ROWS}" m
  from=$(column_of ":d")
  to=$(column_of ":a")

  # Act
  drag "${from}" "${to}"

  # Assert
  wait_for order_is "d a b c"
}

@test "mouse - the grabbed tab slides under the pointer before the button is released" {
  # Arrange
  local from to
  from=$(column_of ":a")
  to=$(column_of ":c")

  # Act
  press_and_move "${from}" "${to}"

  # Assert
  wait_for order_is "b c a d"
}

@test "mouse - a plugin path holding a quote, a space and a hash still slides the tab" {
  # Arrange
  local copy="${BATS_TEST_TMPDIR}/it's #1 plugin" from to
  mkdir -p "${copy}"
  cp -R "${ROOT}/bin" "${ROOT}/lib" "${ROOT}/reorder-revamped.tmux" "${copy}/"
  load_plugin "${copy}"
  from=$(column_of ":a")
  to=$(column_of ":c")

  # Act
  press_and_move "${from}" "${to}"

  # Assert
  wait_for order_is "b c a d"
}

@test "mouse - a mode given to apply on the command line reaches the drop" {
  # Arrange
  local from to
  TMUX="${TMUX_SOCKET},1,0" sh "${ROOT}/bin/reorder-revamped" --mode swap apply
  from=$(column_of ":a")
  to=$(column_of ":c")

  # Act
  drag "${from}" "${to}"

  # Assert
  wait_for order_is "c b a d"
}

pressed_is() {
  local now
  now=$(tmux show-options -gqv @reorder_revamped_pressed)
  [[ "${now}" == "$1" ]]
}

active_is() {
  local now
  now=$(tmux display-message -p -t test: '#{window_name}')
  [[ "${now}" == "$1" ]]
}

@test "mouse - a click on a tab selects its window and leaves no press behind" {
  # Arrange
  local tab window
  tab=$(column_of ":c")
  window=$(tmux display-message -p -t test:=c '#{window_id}')
  send_mouse 0 "${tab}" "${ROWS}" M
  wait_for pressed_is "${window}"

  # Act
  send_mouse 0 "${tab}" "${ROWS}" m

  # Assert
  wait_for pressed_is ""
  wait_for active_is c
  wait_for order_is "a b c d"
}

@test "mouse - a drag that starts on a second click still reorders the windows" {
  # Arrange
  local from to
  from=$(column_of ":a")
  to=$(column_of ":c")
  send_mouse 0 "${from}" "${ROWS}" M
  send_mouse 0 "${from}" "${ROWS}" m

  # Act
  drag "${from}" "${to}"

  # Assert
  wait_for order_is "b c a d"
}

@test "mouse - a drag that starts on a third click still reorders the windows" {
  # Arrange
  local from to
  from=$(column_of ":a")
  to=$(column_of ":c")
  send_mouse 0 "${from}" "${ROWS}" M
  send_mouse 0 "${from}" "${ROWS}" m
  send_mouse 0 "${from}" "${ROWS}" M
  send_mouse 0 "${from}" "${ROWS}" m

  # Act
  drag "${from}" "${to}"

  # Assert
  wait_for order_is "b c a d"
}

@test "mouse - with the live slide off, dropping a tab on the left of the status line moves it to the start" {
  # Arrange
  local from
  TMUX="${TMUX_SOCKET},1,0" sh "${ROOT}/bin/reorder-revamped" --live off apply
  from=$(column_of ":c")

  # Act
  drag "${from}" 2

  # Assert
  wait_for order_is "c a b d"
}

@test "mouse - with the live slide off, dropping a tab on the right of the status line moves it to the end" {
  # Arrange
  local from
  TMUX="${TMUX_SOCKET},1,0" sh "${ROOT}/bin/reorder-revamped" --live off apply
  from=$(column_of ":a")

  # Act
  drag "${from}" $((COLUMNS - 2))

  # Assert
  wait_for order_is "b c d a"
}
