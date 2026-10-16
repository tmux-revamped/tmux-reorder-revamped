#!/usr/bin/env bash

load "${BATS_TEST_DIRNAME}/../helpers.bash"
load "${BATS_TEST_DIRNAME}/../tmux_helpers.bash"

REORDER_WAIT_ATTEMPTS=50
REORDER_WAIT_STEP=0.1

start_reorder_server() {
  setup_test_environment
  setup_tmux_server
  export TMUX="${TMUX_SOCKET},0,0"
  unset TMUX_PANE
  RANDOM=20261016
  WINDOW_NAMES=("a${RANDOM}" "b${RANDOM}" "c${RANDOM}" "d${RANDOM}")
  tmux rename-window -t test: "${WINDOW_NAMES[0]}"
  local name
  for name in "${WINDOW_NAMES[@]:1}"; do
    tmux new-window -d -t test: -n "${name}"
  done
  tmux select-window -t "test:=${WINDOW_NAMES[0]}"
}

stop_reorder_server() {
  teardown_tmux_server
  cleanup_test_environment
}

window_order() {
  tmux list-windows -t test -F '#{window_name}' | paste -sd ' ' -
}

window_id_of() {
  tmux display-message -p -t "test:=${1}" '#{window_id}'
}

test_session_id() {
  tmux display-message -p -t test '#{session_id}'
}

names_in_order() {
  local positions=("$@") joined="" position
  for position in "${positions[@]}"; do
    joined="${joined:+${joined} }${WINDOW_NAMES[position]}"
  done
  printf '%s\n' "${joined}"
}

wait_until() {
  local attempt
  for ((attempt = 0; attempt < REORDER_WAIT_ATTEMPTS; attempt++)); do
    "$@" && return 0
    sleep "${REORDER_WAIT_STEP}"
  done
  return 1
}

order_is() {
  [[ "$(window_order)" == "${1}" ]]
}
