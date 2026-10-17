#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/reorder_helpers.bash"

HOST_ROWS=20
HOST_COLUMNS=160

setup() {
  start_reorder_server
  HOST_SOCKET="${TMUX_SOCKET}-host"
  tmux set-option -g mouse on
  tmux set-option -g status-left '[s] '
  tmux run-shell "bash '${PLUGIN_DIR}/reorder-revamped.tmux'"
  command tmux -S "${HOST_SOCKET}" -f /dev/null new-session -d -s host \
    -x "${HOST_COLUMNS}" -y "${HOST_ROWS}" \
    "env -u TMUX TERM=xterm-256color tmux -S '${TMUX_SOCKET}' attach-session -t test"
  wait_until status_shows "${WINDOW_NAMES[3]}"
}

dump_reorder_state() {
  printf 'order: %s\n' "$(window_order)"
  printf 'status: %s\n' "$(status_line)"
  tmux list-keys -T root 2>/dev/null | grep -E 'Mouse(Down|Drag|DragEnd|Up)1Status'
  tmux show-options -g 2>/dev/null | grep -E '^@reorder'
  tmux show-messages 2>/dev/null | tail -n 20
}

teardown() {
  [[ -n "${BATS_TEST_COMPLETED:-}" ]] || dump_reorder_state 2>&1 | sed 's/^/# /' >&3 || true
  command tmux -S "${HOST_SOCKET}" kill-server 2>/dev/null || true
  rm -f "${HOST_SOCKET}"
  stop_reorder_server
}

status_line() {
  command tmux -S "${HOST_SOCKET}" capture-pane -p -t host | sed -n "${HOST_ROWS}p"
}

status_shows() {
  [[ "$(status_line)" == *"${1}"* ]]
}

column_of() {
  status_line | awk -v name="${1}" '{ print index($0, name) + 1 }'
}

send_mouse() {
  command tmux -S "${HOST_SOCKET}" send-keys -t host -l $'\e[<'"${1};${2};${3}${4}"
}

drag_on_row() {
  local row="${1}" from="${2}" to="${3}" step=1 column
  ((from > to)) && step=-1
  send_mouse 0 "${from}" "${row}" M
  for ((column = from + step; column != to + step; column += step)); do
    send_mouse 32 "${column}" "${row}" M
  done
  send_mouse 0 "${to}" "${row}" m
}

hold_drag_on_row() {
  local row="${1}" from="${2}" to="${3}" step=1 column
  ((from > to)) && step=-1
  send_mouse 0 "${from}" "${row}" M
  for ((column = from + step; column != to + step; column += step)); do
    send_mouse 32 "${column}" "${row}" M
  done
}

@test "dragging a tab onto another tab with the mouse reorders the windows" {
  # Arrange
  local from to
  from="$(column_of "${WINDOW_NAMES[0]}")"
  to="$(column_of "${WINDOW_NAMES[2]}")"

  # Act
  drag_on_row "${HOST_ROWS}" "${from}" "${to}"

  # Assert
  wait_until order_is "$(names_in_order 1 2 0 3)"
}

@test "dragging a tab onto empty status space moves it to the end" {
  # Arrange
  local from
  from="$(column_of "${WINDOW_NAMES[1]}")"

  # Act
  drag_on_row "${HOST_ROWS}" "${from}" $((HOST_COLUMNS / 2))

  # Assert
  wait_until order_is "$(names_in_order 0 2 3 1)"
}

@test "a text drag from a pane that ends on a tab moves nothing" {
  # Arrange
  local tab from_last to_first
  tab="$(column_of "${WINDOW_NAMES[1]}")"
  send_mouse 0 "${tab}" 5 M
  send_mouse 32 "${tab}" $((HOST_ROWS - 1)) M
  send_mouse 32 "${tab}" "${HOST_ROWS}" M
  send_mouse 0 "${tab}" "${HOST_ROWS}" m
  from_last="$(column_of "${WINDOW_NAMES[3]}")"
  to_first="$(column_of "${WINDOW_NAMES[0]}")"

  # Act
  drag_on_row "${HOST_ROWS}" "${from_last}" "${to_first}"

  # Assert
  wait_until order_is "$(names_in_order 3 0 1 2)"
}

@test "the grabbed tab slides under the pointer before the button is released" {
  # Arrange
  local from to
  from="$(column_of "${WINDOW_NAMES[0]}")"
  to="$(column_of "${WINDOW_NAMES[2]}")"

  # Act
  hold_drag_on_row "${HOST_ROWS}" "${from}" "${to}"

  # Assert
  wait_until order_is "$(names_in_order 1 2 0 3)"
}

@test "a plugin path holding a single quote still slides the grabbed tab" {
  # Arrange
  local copy="${TEST_TMPDIR}/it's plugin" from to
  mkdir -p "${copy}"
  cp -R "${PLUGIN_DIR}/src" "${PLUGIN_DIR}/reorder-revamped.tmux" "${copy}/"
  tmux run-shell "bash $(printf '%q' "${copy}/reorder-revamped.tmux")"
  from="$(column_of "${WINDOW_NAMES[0]}")"
  to="$(column_of "${WINDOW_NAMES[2]}")"

  # Act
  hold_drag_on_row "${HOST_ROWS}" "${from}" "${to}"

  # Assert
  wait_until order_is "$(names_in_order 1 2 0 3)"
}
