#!/usr/bin/env bash
# shellcheck disable=SC2030,SC2031,SC2034,SC2154

# shellcheck source=test/tmux_helpers.bash
source "${BATS_TEST_DIRNAME:-.}/tmux_helpers.bash"

ROWS=20
COLUMNS=160

setup() {
  ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  setup_tmux_server
  HOST="${TMUX_SOCKET}-host"
  tmux rename-window -t test: a
  tmux new-window -d -t test: -n b
  tmux new-window -d -t test: -n c
  tmux new-window -d -t test: -n d
  tmux select-window -t test:=a
  tmux set-option -g mouse on
  tmux set-option -g status-left '[s] '
  load_plugin "${ROOT}"
  command tmux -S "${HOST}" -f /dev/null new-session -d -s host -x "${COLUMNS}" -y "${ROWS}" \
    "env -u TMUX TERM=xterm-256color tmux -S '${TMUX_SOCKET}' attach-session -t test"
  wait_for status_shows ":d"
}

teardown() {
  command tmux -S "${HOST}" kill-server 2>/dev/null || :
  rm -f "${HOST}"
  teardown_tmux_server
}

load_plugin() {
  local quoted
  quoted=$(printf '%s' "$1" | sed "s/'/'\\\\''/g")
  tmux run-shell "'${quoted}/reorder-revamped.tmux'"
}

wait_for() {
  local delay
  for delay in 0.01 0.02 0.05 0.1 0.1 0.2 0.2 0.5 0.5 1 1 1 2 2; do
    "$@" && return 0
    sleep "${delay}"
  done
  "$@"
}

order() {
  local names
  names=$(tmux list-windows -t test -F '#{window_name}')
  paste -sd ' ' - <<<"${names}"
}

order_is() {
  local now
  now=$(order)
  [[ "${now}" == "$1" ]]
}

status_line() {
  local screen
  screen=$(command tmux -S "${HOST}" capture-pane -p -t host)
  sed -n "${ROWS}p" <<<"${screen}"
}

status_shows() {
  local line
  line=$(status_line)
  [[ "${line}" == *"$1"* ]]
}

column_of() {
  local line
  line=$(status_line)
  awk -v name="$1" '{ print index($0, name) + 1 }' <<<"${line}"
}

send_mouse() {
  command tmux -S "${HOST}" send-keys -t host -l $'\e[<'"$1;$2;$3$4"
}

press_and_move() {
  local from="$1" to="$2" step=1 column
  ((from > to)) && step=-1
  send_mouse 0 "${from}" "${ROWS}" M
  for ((column = from + step; column != to + step; column += step)); do
    send_mouse 32 "${column}" "${ROWS}" M
  done
}

drag() {
  press_and_move "$1" "$2"
  send_mouse 0 "$2" "${ROWS}" m
}
