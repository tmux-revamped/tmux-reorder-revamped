#!/usr/bin/env bats
# shellcheck disable=SC2034

load "${BATS_TEST_DIRNAME}/mocks.bash"

setup() {
  setup_reorder_mocks
}

teardown() {
  cleanup_test_environment
}

binding_for() {
  local key="${1}" line
  for line in "${lines[@]}"; do
    [[ "${line}" == "tmux bind-key -n ${key} "* ]] && { printf '%s\n' "${line}"; return 0; }
  done
  return 1
}

@test "apply on tmux 3.8 measures the tabs when a drag starts" {
  # Arrange
  MOCK_VERSION="tmux 3.8"

  # Act
  run reorder_apply

  # Assert
  local drag
  drag="$(binding_for MouseDrag1Status)"
  [[ "${drag}" == *" grab '#{session_id}' '#{client_name}'"* ]]
  [[ "${drag}" == *"set-option -gF -t = @reorder_revamped_probe #{E:@reorder_revamped_hit}"* ]]
  [[ "${drag}" == *" slide '#{session_id}' '#{@reorder_revamped_source}' '#{@reorder_revamped_probe}' '#{client_name}' 1"* ]]
}

@test "apply records the source only for a drag that began with a press on a tab" {
  # Arrange
  local expected="if-shell -F #{&&:#{@reorder_revamped_pressed},#{&&:#{e|<=:#{e|-:#{client_activity},#{@reorder_revamped_pressed_at}},10},#{||:#{==:#{@reorder_revamped_source},},#{e|>:#{e|-:#{client_activity},#{@reorder_revamped_seen}},2}}}} set-option -gF @reorder_revamped_source '#{@reorder_revamped_pressed}'"

  # Act
  run reorder_apply

  # Assert
  [[ "$(binding_for MouseDrag1Status)" == *"${expected}"* ]]
}

@test "apply wraps the stock press binding and keeps its command" {
  # Arrange
  MOCK_KEYS="bind-key    -T root         MouseDown1Status          switch-client -t ="

  # Act
  run reorder_apply

  # Assert
  [[ "$(binding_for MouseDown1Status)" == "tmux bind-key -n MouseDown1Status set-option -gF -t = @reorder_revamped_pressed #{window_id} \\; set-option -gF @reorder_revamped_pressed_at #{client_activity} \\; if-shell -F 1 switch-client -t =" ]]
}

@test "apply reuses the saved press command instead of wrapping its own wrapper" {
  # Arrange
  MOCK_KEYS="bind-key -T root MouseDown1Status set-option -Fg -t = @reorder_revamped_pressed x"
  MOCK_OPTIONS=("@reorder_revamped_press_original=select-window -t =")

  # Act
  run reorder_apply

  # Assert
  [[ "$(binding_for MouseDown1Status)" == *"\\; if-shell -F 1 select-window -t =" ]]
}

@test "apply records the press alone when nothing was bound to it" {
  # Arrange
  MOCK_KEYS=""

  # Act
  run reorder_apply

  # Assert
  [[ "$(binding_for MouseDown1Status)" != *"if-shell"* ]]
}

@test "apply clears the press on release when the release key is free" {
  # Arrange
  MOCK_KEYS=""

  # Act
  run reorder_apply

  # Assert
  [[ "$(binding_for MouseUp1Status)" == "tmux bind-key -n MouseUp1Status set-option -gu @reorder_revamped_pressed \\; set-option -gu @reorder_revamped_pressed_at" ]]
}

@test "apply leaves a release binding it does not own" {
  # Arrange
  MOCK_KEYS="bind-key -T root MouseUp1Status display-message mine"

  # Act
  run reorder_apply

  # Assert
  run binding_for MouseUp1Status
  [[ "${status}" -eq 1 ]]
}

@test "apply before tmux 3.8 slides by the window under the pointer" {
  # Arrange
  MOCK_VERSION="tmux 3.7c"

  # Act
  run reorder_apply

  # Assert
  [[ "${lines[0]}" == "tmux set-option -g @reorder_revamped_hit #{window_id}" ]]
  [[ "$(binding_for MouseDrag1Status)" != *" grab "* ]]
  [[ "$(binding_for MouseDrag1Status)" == *"' 0"* ]]
}

@test "apply binds no live slide in swap mode" {
  # Arrange
  MOCK_OPTIONS=("@reorder_revamped_mode=swap")

  # Act
  run reorder_apply

  # Assert
  [[ "$(binding_for MouseDrag1Status)" != *"probe"* ]]
}

@test "apply binds no live slide when live is off" {
  # Arrange
  MOCK_OPTIONS=("@reorder_revamped_live=off")

  # Act
  run reorder_apply

  # Assert
  [[ "$(binding_for MouseDrag1Status)" != *"probe"* ]]
}

@test "apply binds the drop on a tab and clears every drag option" {
  # Arrange
  local self
  self="$(reorder_quote_for_run_shell "${REORDER_SELF}")"

  # Act
  run reorder_apply

  # Assert
  [[ "$(binding_for MouseDragEnd1Status)" == "tmux bind-key -n MouseDragEnd1Status run-shell -b -t = bash ${self} drop '#{session_id}' '#{@reorder_revamped_source}:#{@reorder_revamped_seen}' '#{window_id}' '#{client_activity}' \\; set-option -gu @reorder_revamped_source \\; set-option -gu @reorder_revamped_seen \\; set-option -gu @reorder_revamped_hover \\; set-option -gu @reorder_revamped_probe \\; set-option -gu @reorder_revamped_pressed \\; set-option -gu @reorder_revamped_pressed_at" ]]
}

@test "apply binds the three edge drops by default" {
  # Arrange
  MOCK_OPTIONS=()

  # Act
  run reorder_apply

  # Assert
  [[ "$(binding_for MouseDragEnd1StatusLeft)" == *"run-shell -b bash "*" edge first "* ]]
  [[ "$(binding_for MouseDragEnd1StatusRight)" == *"run-shell -b bash "*" edge last "* ]]
  [[ "$(binding_for MouseDragEnd1StatusDefault)" == *"run-shell -b bash "*" edge trailing "* ]]
}

@test "apply skips the edge drops when edges are off" {
  # Arrange
  MOCK_OPTIONS=("@reorder_revamped_edges=off")

  # Act
  run reorder_apply

  # Assert
  [[ "${output}" != *"MouseDragEnd1StatusLeft"* ]]
}

@test "apply releases its own edge bindings when edges are turned off" {
  # Arrange
  MOCK_OPTIONS=("@reorder_revamped_edges=off")
  MOCK_KEYS="bind-key -T root MouseDragEnd1StatusLeft run-shell -b \"bash '${REORDER_SELF}' edge first\""$'\n'"bind-key -T root MouseDragEnd1StatusRight run-shell -b \"bash '${REORDER_SELF}' edge last\""$'\n'"bind-key -T root MouseDragEnd1StatusDefault run-shell -b \"bash '${REORDER_SELF}' edge trailing\""

  # Act
  run reorder_apply

  # Assert
  [[ "${output}" == *"tmux unbind-key -n MouseDragEnd1StatusLeft"* ]]
  [[ "${output}" == *"tmux unbind-key -n MouseDragEnd1StatusRight"* ]]
  [[ "${output}" == *"tmux unbind-key -n MouseDragEnd1StatusDefault"* ]]
}

@test "apply leaves an edge binding it does not own when edges are off" {
  # Arrange
  MOCK_OPTIONS=("@reorder_revamped_edges=off")
  MOCK_KEYS="bind-key -T root MouseDragEnd1StatusLeft display-message mine"

  # Act
  run reorder_apply

  # Assert
  [[ "${output}" != *"unbind-key"* ]]
}

@test "apply binds nothing below tmux 3.2" {
  # Arrange
  MOCK_VERSION="tmux 3.1c"

  # Act
  run reorder_apply

  # Assert
  [[ "${status}" -eq 0 && -z "${output}" ]]
}
