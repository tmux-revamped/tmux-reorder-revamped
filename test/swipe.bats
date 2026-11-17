#!/usr/bin/env bats
# shellcheck disable=SC2016,SC2030,SC2031,SC2034,SC2154

# shellcheck source=test/mouse_helpers.bash
source "${BATS_TEST_DIRNAME:-.}/mouse_helpers.bash"

bats_require_minimum_version 1.5.0

RIGHT=2
RIGHT_MOVE=34

swipe_on() {
  tmux set-option -g @reorder_revamped_swipe on
  load_plugin "${ROOT}"
}

swipe() {
  send_mouse "${RIGHT}" "$1" "$2" M
  send_mouse "${RIGHT_MOVE}" $((($1 + $3) / 2)) $((($2 + $4) / 2)) M
  send_mouse "${RIGHT_MOVE}" "$3" "$4" M
  send_mouse "${RIGHT}" "$3" "$4" m
}

right_click() {
  send_mouse "${RIGHT}" "$1" "$2" M
  send_mouse "${RIGHT}" "$1" "$2" m
}

shows() {
  local now
  now=$(tmux display-message -p -t "$1" "$2" 2>/dev/null)
  [[ "${now}" == "$3" ]]
}

client_on() {
  local client where
  client=$(tmux list-clients -F '#{client_name}')
  where=$(tmux display-message -p -c "${client%%$'\n'*}" '#{session_name}')
  [[ "${where}" == "$1" ]]
}

screen_shows() {
  local screen
  screen=$(command tmux -S "${HOST}" capture-pane -p -t host)
  [[ "${screen}" == *"$1"* ]]
}

pane_counts() {
  local screen count
  screen=$(tmux capture-pane -p -S - -t "$1")
  count=$(grep -c -- "$2" <<<"${screen}")
  [[ "${count}" == "$3" ]]
}

root_key() {
  local table
  table=$(tmux list-keys -T root)
  sed -n -E "s/^bind-key +-T +root +$1 +//p" <<<"${table}"
}

stock_key() {
  local fresh="${TMUX_SOCKET}-fresh" table
  command tmux -S "${fresh}" -f /dev/null new-session -d -s fresh
  table=$(command tmux -S "${fresh}" list-keys -T root)
  command tmux -S "${fresh}" kill-server
  rm -f "${fresh}"
  sed -n -E "s/^bind-key +-T +root +$1 +//p" <<<"${table}"
}

mouse_reader() {
  local script="${BATS_TEST_TMPDIR}/reader"
  printf '%s\n' '#!/bin/sh' "printf '\\033[?1002h\\033[?1006h'" 'stty -icanon -isig -echo' 'echo ready' 'while :; do dd bs=1 count=1 2>/dev/null | od -An -tx1; done' >"${script}"
  chmod +x "${script}"
  tmux respawn-pane -k -t test:a "sh '${script}'"
  wait_for shows test:a '#{mouse_any_flag}' 1
}

session_tabs() {
  tmux new-session -d -s other -n z
  tmux set-option -g status-left-length 40
  tmux set-option -g status-left '#{S:#[range=session|#{session_id}]<#{session_name}>#[norange] }'
  wait_for status_shows "<other>"
}

@test "swipe - a right-button swipe to the right goes to the next window" {
  # Arrange
  swipe_on

  # Act
  swipe 20 5 60 5

  # Assert
  wait_for shows test: '#{window_name}' b
}

@test "swipe - a swipe to the left goes to the previous window" {
  # Arrange
  swipe_on

  # Act
  swipe 60 5 20 6

  # Assert
  wait_for shows test: '#{window_name}' d
}

@test "swipe - a swipe down goes to the next session" {
  # Arrange
  tmux new-session -d -s other
  swipe_on

  # Act
  swipe 20 3 22 12

  # Assert
  wait_for client_on other
  shows test: '#{window_name}' a
}

@test "swipe - a swipe up goes to the previous session" {
  # Arrange
  tmux new-session -d -s other
  tmux new-session -d -s zeta
  swipe_on

  # Act
  swipe 20 12 20 3

  # Assert
  wait_for client_on other
}

@test "swipe - a swipe as wide as it is tall goes nowhere" {
  # Arrange
  tmux new-session -d -s other
  tmux bind-key -n F9 set-option -g @swipe_done 1
  swipe_on

  # Act
  swipe 20 3 26 9

  # Assert
  command tmux -S "${HOST}" send-keys -t host F9
  wait_for shows test: '#{@swipe_done}' 1
  wait_for shows test: '#{@reorder_revamped_swipe_from}' ''
  client_on test
  shows test: '#{window_name}' a
}

@test "swipe - a right click without a swipe still opens the pane menu, on release" {
  # Arrange
  swipe_on

  # Act
  right_click 20 5

  # Assert
  wait_for screen_shows "Horizontal Split"
}

@test "swipe - a right-button binding of the person's own runs on release" {
  # Arrange
  tmux bind-key -n MouseDown3Pane set-option -g @mine yes
  swipe_on

  # Act
  right_click 20 5

  # Assert
  wait_for shows test: '#{@mine}' yes
}

@test "swipe - with the right button unbound, a swipe still works" {
  # Arrange
  tmux unbind-key -n MouseDown3Pane
  swipe_on

  # Act
  swipe 20 5 60 5

  # Assert
  wait_for shows test: '#{window_name}' b
}

@test "swipe - an app that asked for the mouse gets the press, the motion and the release" {
  # Arrange
  swipe_on
  mouse_reader

  # Act
  swipe 20 5 60 5

  # Assert
  wait_for pane_counts test:a ' 6d$' 1
  wait_for pane_counts test:a ' 4d$' 3
  shows test: '#{window_name}' a
}

@test "swipe - loading the plugin again keeps the original right-button binding" {
  # Arrange
  local stock
  stock=$(root_key MouseDown3Pane)
  swipe_on

  # Act
  load_plugin "${ROOT}"

  # Assert
  run tmux show-option -gqv @reorder_revamped_swipe_original
  [[ "${output}" == "${stock}" ]]
}

@test "swipe - turning it off puts the right-button binding back and unbinds the rest" {
  # Arrange
  local stock
  stock=$(root_key MouseDown3Pane)
  swipe_on
  tmux set-option -g @reorder_revamped_swipe off

  # Act
  load_plugin "${ROOT}"

  # Assert
  run root_key MouseDown3Pane
  [[ "${output}" == "${stock}" ]]
  run root_key MouseDrag3Pane
  [[ -z "${output}" ]]
  run root_key MouseDragEnd3Pane
  [[ -z "${output}" ]]
  run root_key MouseUp3Pane
  [[ -z "${output}" ]]
}

@test "swipe - off by default, the right button keeps its stock binding" {
  # Arrange
  local stock drag
  stock=$(stock_key MouseDown3Pane)
  drag=$(root_key MouseDrag3Pane)

  # Act
  run root_key MouseDown3Pane

  # Assert
  [[ -n "${stock}" ]]
  [[ "${output}" == "${stock}" ]]
  [[ -z "${drag}" ]]
}

@test "session - a tab dropped on another session's name moves the window there" {
  # Arrange
  local from to
  session_tabs
  from=$(column_of ":b")
  to=$(column_of "other")

  # Act
  drag "${from}" "${to}"

  # Assert
  wait_for order_is "a c d"
  run tmux list-windows -t other -F '#{window_name}'
  [[ "${output}" == $'z\nb' ]]
  client_on test
}

@test "session - a tab dropped on its own session's name stays where it is" {
  # Arrange
  local from to
  session_tabs
  tmux set-option -g @reorder_revamped_live off
  load_plugin "${ROOT}"
  tmux bind-key -n F9 set-option -g @drop_done 1
  from=$(column_of ":b")
  to=$(column_of "test")

  # Act
  drag "${from}" "${to}"

  # Assert
  command tmux -S "${HOST}" send-keys -t host F9
  wait_for shows test: '#{@drop_done}' 1
  wait_for shows test: '#{@reorder_revamped_source}' ''
  order_is "a b c d"
}
