#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031,SC2034,SC2154

# shellcheck source=test/tmux_helpers.bash
source "${BATS_TEST_DIRNAME:-.}/tmux_helpers.bash"

bats_require_minimum_version 1.5.0

setup() {
  ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  setup_tmux_server
  tmux rename-window -t test: a
  tmux new-window -d -t test: -n b
  tmux new-window -d -t test: -n c
  tmux new-window -d -t test: -n d
  tmux select-window -t test:=a
  SESSION=$(tmux display-message -p -t test '#{session_id}')
}

teardown() {
  teardown_tmux_server
}

load_plugin() {
  local quoted
  quoted=$(printf '%s' "$1" | sed "s/'/'\\\\''/g")
  tmux run-shell "'${quoted}/reorder-revamped.tmux'"
}

key_binding() {
  local table
  table=$(tmux list-keys -T root)
  awk -v key="$1" '{ for (i = 1; i < NF; i++) { if ($i == "-T") { if ($(i + 2) == key) { print } break } } }' <<<"${table}"
}

order() {
  local names
  names=$(tmux list-windows -t test -F '#{window_name}')
  paste -sd ' ' - <<<"${names}"
}

id_of() {
  tmux display-message -p -t "test:=$1" '#{window_id}'
}

tool() {
  # shellcheck disable=SC2086
  TMUX="${TMUX_SOCKET},1,0" run ${REVAMPED_TEST_SHELL:-sh} "${ROOT}/bin/reorder-revamped" "$@"
}

@test "entrypoint - loading binds the drag, the drop and every edge" {
  # Arrange
  local keys=(MouseDown1Status SecondClick1Status TripleClick1Status MouseUp1Status MouseDrag1Status MouseDragEnd1Status MouseDragEnd1StatusLeft MouseDragEnd1StatusRight MouseDragEnd1StatusDefault)

  # Act
  load_plugin "${ROOT}"

  # Assert
  for key in "${keys[@]}"; do
    run key_binding "${key}"
    [[ "${output}" == *"@reorder_revamped_"* ]]
  done
}

@test "entrypoint - the stock press binding is wrapped and kept running" {
  # Arrange
  local stock
  stock=$(key_binding MouseDown1Status)
  stock=$(sed -E 's/^bind-key +-T root +MouseDown1Status +//' <<<"${stock}")

  # Act
  load_plugin "${ROOT}"

  # Assert
  run get_option @reorder_revamped_press_original
  [[ "${output}" == "${stock}" ]]
  run key_binding MouseDown1Status
  [[ "${output}" == *"if-shell -F 1 \"${stock}\""* || "${output}" == *"if-shell -F 1 ${stock}"* ]]
}

@test "entrypoint - a second load reuses the saved press command instead of wrapping its own" {
  # Arrange
  load_plugin "${ROOT}"
  local first
  first=$(key_binding MouseDown1Status)

  # Act
  load_plugin "${ROOT}"

  # Assert
  run key_binding MouseDown1Status
  [[ "${output}" == "${first}" ]]
}

@test "entrypoint - a press with nothing bound to it is recorded alone" {
  # Arrange
  tmux unbind-key -n MouseDown1Status

  # Act
  load_plugin "${ROOT}"

  # Assert
  run key_binding MouseDown1Status
  [[ "${output}" != *if-shell* ]]
  run tmux show-options -gqv @reorder_revamped_press_original
  [[ -z "${output}" ]]
}

@test "entrypoint - release and click bindings the person owns are left alone" {
  # Arrange
  tmux bind-key -n MouseUp1Status display-message up
  tmux bind-key -n SecondClick1Status display-message twice

  # Act
  load_plugin "${ROOT}"

  # Assert
  run key_binding MouseUp1Status
  [[ "${output}" == *"display-message up"* ]]
  run key_binding SecondClick1Status
  [[ "${output}" == *"display-message twice"* ]]
}

@test "entrypoint - turning edges off releases its own edge bindings and keeps a foreign one" {
  # Arrange
  load_plugin "${ROOT}"
  tmux bind-key -n MouseDragEnd1StatusDefault display-message mine
  tmux set-option -g @reorder_revamped_edges off

  # Act
  load_plugin "${ROOT}"

  # Assert
  run key_binding MouseDragEnd1StatusLeft
  [[ -z "${output}" ]]
  run key_binding MouseDragEnd1StatusDefault
  [[ "${output}" == *"display-message mine"* ]]
}

@test "entrypoint - git tracks the entry point and the tool as executable" {
  # Arrange
  local entry=reorder-revamped.tmux tool=bin/reorder-revamped

  # Act
  run git -C "${ROOT}" ls-files --stage -- "${entry}" "${tool}"

  # Assert
  [[ "${lines[0]}" == 100755\ * ]]
  [[ "${lines[1]}" == 100755\ * ]]
}

@test "drop - the first window dropped on the third is inserted there and made current" {
  # Arrange
  local a c at
  a=$(id_of a)
  c=$(id_of c)
  at=1000

  # Act
  tool drop "${SESSION}" "${a}:${at}" "${c}" "${at}"

  # Assert
  run order
  [[ "${output}" == "b c a d" ]]
  run tmux display-message -p -t test '#{window_name}'
  [[ "${output}" == a ]]
}

@test "drop - the last window dropped on the second is inserted there" {
  # Arrange
  local d b at
  d=$(id_of d)
  b=$(id_of b)
  at=1000

  # Act
  tool drop "${SESSION}" "${d}:${at}" "${b}" "${at}"

  # Assert
  run order
  [[ "${output}" == "a d b c" ]]
}

@test "drop - swap mode exchanges only the two windows" {
  # Arrange
  local a c at
  a=$(id_of a)
  c=$(id_of c)
  at=1000
  tmux set-option -g @reorder_revamped_mode swap

  # Act
  tool drop "${SESSION}" "${a}:${at}" "${c}" "${at}"

  # Assert
  run order
  [[ "${output}" == "c b a d" ]]
}

@test "drop - index gaps are walked by their real indices" {
  # Arrange
  local a d at
  tmux move-window -s test:=d -t test:9
  a=$(id_of a)
  d=$(id_of d)
  at=1000

  # Act
  tool drop "${SESSION}" "${a}:${at}" "${d}" "${at}"

  # Assert
  run order
  [[ "${output}" == "b c d a" ]]
}

@test "drop - a stale, missing, self or closed source moves nothing" {
  # Arrange
  local a b c at
  a=$(id_of a)
  b=$(id_of b)
  c=$(id_of c)
  at=1000
  tmux kill-window -t test:=c

  # Act
  tool drop "${SESSION}" "${a}:$((at - 11))" "${b}" "${at}"
  tool drop "${SESSION}" "" "${b}" "${at}"
  tool drop "${SESSION}" "${a}:${at}" "${a}" "${at}"
  tool drop "${SESSION}" "${c}:${at}" "${b}" "${at}"
  tool drop "${SESSION}" "${a}:${at}" "${c}" "${at}"

  # Assert
  run order
  [[ "${output}" == "a b d" ]]
}

@test "drop - a timeout that is not a number falls back to ten seconds" {
  # Arrange
  local a b at
  a=$(id_of a)
  b=$(id_of b)
  at=1000
  tmux set-option -g @reorder_revamped_timeout soon

  # Act
  tool drop "${SESSION}" "${a}:$((at - 10))" "${b}" "${at}"

  # Assert
  run order
  [[ "${output}" == "b a c d" ]]
}

@test "drop - a configured timeout is honoured" {
  # Arrange
  local a b at
  a=$(id_of a)
  b=$(id_of b)
  at=1000
  tmux set-option -g @reorder_revamped_timeout 2

  # Act
  tool drop "${SESSION}" "${a}:$((at - 3))" "${b}" "${at}"

  # Assert
  run order
  [[ "${output}" == "a b c d" ]]
}

@test "edge - first and last move the window to an end of the list" {
  # Arrange
  local c b at
  c=$(id_of c)
  b=$(id_of b)
  at=1000

  # Act
  tool edge first "${SESSION}" "${c}:${at}" "${at}"
  tool edge last "${SESSION}" "${b}:${at}" "${at}"

  # Assert
  run order
  [[ "${output}" == "c a d b" ]]
}

@test "edge - the trailing edge moves to the end of a left list and nothing for a centred one" {
  # Arrange
  local a b at
  a=$(id_of a)
  b=$(id_of b)
  at=1000
  tool edge trailing "${SESSION}" "${a}:${at}" "${at}"
  tmux set-option -g status-justify centre

  # Act
  tool edge trailing "${SESSION}" "${b}:${at}" "${at}"

  # Assert
  run order
  [[ "${output}" == "b c d a" ]]
}

@test "edge - a window already at the edge stays put" {
  # Arrange
  local a at
  a=$(id_of a)
  at=1000

  # Act
  tool edge first "${SESSION}" "${a}:${at}" "${at}"

  # Assert
  [[ "${status}" -eq 0 ]]
  run order
  [[ "${output}" == "a b c d" ]]
}

@test "slide - the grabbed window moves onto the hovered tab" {
  # Arrange
  local a c
  a=$(id_of a)
  c=$(id_of c)

  # Act
  tool slide "${SESSION}" "${a}" "${c}" "" 0

  # Assert
  run order
  [[ "${output}" == "b c a d" ]]
}

@test "slide - remeasuring writes the hit format in the same command" {
  # Arrange
  local a c
  a=$(id_of a)
  c=$(id_of c)
  tmux set-option -g @reorder_revamped_hit stale

  # Act
  tool slide "${SESSION}" "${a}" "${c}" "" 1

  # Assert
  run order
  [[ "${output}" == "b c a d" ]]
  run tmux show-options -gqv @reorder_revamped_hit
  [[ "${output}" != stale ]]
}

@test "slide - the same tab or a closed window moves nothing" {
  # Arrange
  local a d
  a=$(id_of a)
  d=$(id_of d)
  tmux kill-window -t test:=d

  # Act
  tool slide "${SESSION}" "${a}" "${a}" "" 0
  tool slide "${SESSION}" "${a}" "${d}" "" 0
  tool slide "${SESSION}" "${d}" "${a}" "" 0

  # Assert
  run order
  [[ "${output}" == "a b c" ]]
}

@test "grab - the hit format is written for the session" {
  # Arrange
  tmux set-option -g @reorder_revamped_hit stale

  # Act
  tool grab "${SESSION}" ""

  # Assert
  [[ "${status}" -eq 0 ]]
  run tmux show-options -gqv @reorder_revamped_hit
  [[ "${output}" != stale ]]
}
