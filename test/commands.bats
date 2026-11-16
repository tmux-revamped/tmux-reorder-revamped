#!/usr/bin/env bats
# shellcheck disable=SC2016,SC2030,SC2031,SC2034

# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

bats_require_minimum_version 1.5.0

setup() {
  harness_setup
  for name in $(compgen -v REORDER_REVAMPED_) KODOUGU_THEME KODOUGU_ACCENT NO_COLOR; do
    unset "${name}"
  done
}

tool() {
  # shellcheck disable=SC2086
  run ${REVAMPED_TEST_SHELL:-sh} "${REVAMPED_TESTS_DIR}/../bin/reorder-revamped" "$@"
}

plain_tty() {
  local shell_words
  read -r -a shell_words <<<"${REVAMPED_TEST_SHELL:-sh}"
  run python3 "${REVAMPED_TESTS_DIR}/on_tty.py" "${shell_words[@]}" "${REVAMPED_TESTS_DIR}/../bin/reorder-revamped"
}

@test "commands - list prints every binding apply would make" {
  # Arrange
  local command=list

  # Act
  tool "${command}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${lines[0]}" == "set-option -g @reorder_revamped_hit #{window_id}" ]]
  [[ "${#lines[@]}" -eq 11 ]]
}

@test "commands - list --json prints one JSON object" {
  # Arrange
  export REVAMPED_TEST_TMUX_VERSION=3.1

  # Act
  tool list --json

  # Assert
  [[ "${output}" == '{"bindings":[]}' ]]
}

@test "commands - an option in both forms wins over the environment" {
  # Arrange
  export REORDER_REVAMPED_EDGES=on REORDER_REVAMPED_MODE=insert

  # Act
  tool --edges=off --mode swap list

  # Assert
  [[ "${output}" != *" edge "* ]]
  [[ "${output}" != *"#{E:@reorder_revamped_hit}"* ]]
}

@test "commands - apply sends the plan in one tmux call and prints nothing" {
  # Arrange
  export REVAMPED_TEST_TMUX_ARGV="${BATS_TEST_TMPDIR}/argv"

  # Act
  # shellcheck disable=SC2086
  run --separate-stderr ${REVAMPED_TEST_SHELL:-sh} "${REVAMPED_TESTS_DIR}/../bin/reorder-revamped" apply

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ -z "${output}" ]]
  run grep -c '^set-option|-g|@reorder_revamped_hit|#{window_id}|;|set-option|' "${REVAMPED_TEST_TMUX_ARGV}"
  [[ "${output}" == "1" ]]
}

@test "commands - the menu applies the keys and counts them" {
  # Arrange
  harness_hide gum

  # Act
  plain_tty <<<"2"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Applied. 9 keys are bound."* ]]
}

@test "commands - the menu runs doctor" {
  # Arrange
  harness_hide gum

  # Act
  plain_tty <<<"3"

  # Assert
  [[ "${output}" =~ tmux\ +ok ]]
}

@test "commands - an unknown option is a usage error even without a value" {
  # Arrange
  local option=--colour

  # Act
  tool "${option}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "reorder-revamped: unknown option '--colour'. run 'reorder-revamped help' for usage." ]]
}

@test "commands - an unknown option with a value is a usage error" {
  # Arrange
  local option=--colour=red

  # Act
  tool "${option}" list

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "reorder-revamped: unknown option '--colour'. run 'reorder-revamped help' for usage." ]]
}

@test "commands - a setting option without its value is a usage error" {
  # Arrange
  local option=--timeout

  # Act
  tool list "${option}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "reorder-revamped: option '--timeout' needs a value. run 'reorder-revamped help' for usage." ]]
}

@test "commands - a single-dash option is a usage error" {
  # Arrange
  local option=-x

  # Act
  tool "${option}"

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "reorder-revamped: unknown option '-x'. run 'reorder-revamped help' for usage." ]]
}

@test "commands - --json with any command but list is a usage error" {
  # Arrange
  local flag=--json

  # Act
  tool "${flag}" apply

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "reorder-revamped: option '--json' works only with list. run 'reorder-revamped help' for usage." ]]
}

@test "commands - -- ends the options" {
  # Arrange
  local command=list

  # Act
  tool --theme nord -- "${command}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${lines[0]}" == set-option\ * ]]
}

@test "commands - an inherited guard variable of the plugin is ignored" {
  # Arrange
  export REORDER_REVAMPED_REORDER_LOADED=1 REORDER_REVAMPED_CORE_LOADED=1

  # Act
  tool version

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${lines[0]}" =~ ^reorder-revamped\ [0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "commands - drop, edge, grab and slide run without the interface" {
  # Arrange
  export REVAMPED_TEST_TMUX_ARGV="${BATS_TEST_TMPDIR}/argv"
  harness_hide gum

  # Act
  tool drop '$1' "@1:1000" @1 1000
  tool edge first '$1' "" 1000
  tool slide '$1' @1 @1 "" 0
  # shellcheck disable=SC2086
  run --separate-stderr ${REVAMPED_TEST_SHELL:-sh} "${REVAMPED_TESTS_DIR}/../bin/reorder-revamped" grab '$1' ""

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ -z "${output}" ]]
  run grep -c '^set-option|-g|@reorder_revamped_hit|$' "${REVAMPED_TEST_TMUX_ARGV}"
  [[ "${output}" == "1" ]]
}
