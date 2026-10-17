#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../helpers.bash"

setup() {
  setup_test_environment
  source "${BATS_TEST_DIRNAME}/../../../src/lib/reorder/plan.sh"
}

teardown() {
  cleanup_test_environment
}

@test "reorder_parse_version reads major and minor from a release" {
  # Arrange
  local banner="tmux 3.8"

  # Act
  run reorder_parse_version "${banner}"

  # Assert
  [[ "${output}" == "3 8" ]]
}

@test "reorder_parse_version drops a patch letter" {
  # Arrange
  local banner="tmux 3.2a"

  # Act
  run reorder_parse_version "${banner}"

  # Assert
  [[ "${output}" == "3 2" ]]
}

@test "reorder_parse_version reads a next- prerelease" {
  # Arrange
  local banner="tmux next-3.9"

  # Act
  run reorder_parse_version "${banner}"

  # Assert
  [[ "${output}" == "3 9" ]]
}

@test "reorder_parse_version prints nothing for a master build" {
  # Arrange
  local banner="tmux master"

  # Act
  run reorder_parse_version "${banner}"

  # Assert
  [[ -z "${output}" ]]
}

@test "reorder_version_supported accepts the minimum" {
  # Arrange
  local have="3 2"

  # Act
  run reorder_version_supported "${have}" "3.2"

  # Assert
  [[ "${status}" -eq 0 ]]
}

@test "reorder_version_supported rejects an older minor" {
  # Arrange
  local have="3 1"

  # Act
  run reorder_version_supported "${have}" "3.2"

  # Assert
  [[ "${status}" -eq 1 ]]
}

@test "reorder_version_supported rejects an older major" {
  # Arrange
  local have="2 9"

  # Act
  run reorder_version_supported "${have}" "3.2"

  # Assert
  [[ "${status}" -eq 1 ]]
}

@test "reorder_version_supported accepts a newer major with a lower minor" {
  # Arrange
  local have="4 0"

  # Act
  run reorder_version_supported "${have}" "3.2"

  # Assert
  [[ "${status}" -eq 0 ]]
}

@test "reorder_version_supported compares a two-digit minor numerically" {
  # Arrange
  local have="3 10"

  # Act
  run reorder_version_supported "${have}" "3.9"

  # Assert
  [[ "${status}" -eq 0 ]]
}

@test "reorder_version_supported accepts an unparsed version" {
  # Arrange
  local have=""

  # Act
  run reorder_version_supported "${have}" "3.2"

  # Assert
  [[ "${status}" -eq 0 ]]
}

@test "reorder_position_of prints the zero-based position" {
  # Arrange
  local ids=(@4 @9 @2)

  # Act
  run reorder_position_of @2 "${ids[@]}"

  # Assert
  [[ "${status}" -eq 0 && "${output}" == "2" ]]
}

@test "reorder_position_of fails for an absent id" {
  # Arrange
  local ids=(@4 @9)

  # Act
  run reorder_position_of @7 "${ids[@]}"

  # Assert
  [[ "${status}" -eq 1 && -z "${output}" ]]
}

@test "reorder_path steps forward to the target" {
  # Arrange
  local from=0 to=3

  # Act
  run reorder_path "${from}" "${to}"

  # Assert
  [[ "${output}" == $'1\n2\n3' ]]
}

@test "reorder_path steps backward to the target" {
  # Arrange
  local from=3 to=1

  # Act
  run reorder_path "${from}" "${to}"

  # Assert
  [[ "${output}" == $'2\n1' ]]
}

@test "reorder_path prints nothing when already in place" {
  # Arrange
  local from=2 to=2

  # Act
  run reorder_path "${from}" "${to}"

  # Assert
  [[ -z "${output}" ]]
}

@test "reorder_is_fresh accepts a source inside the timeout" {
  # Arrange
  local recorded=1000 now=1010

  # Act
  run reorder_is_fresh "${recorded}" "${now}" 10

  # Assert
  [[ "${status}" -eq 0 ]]
}

@test "reorder_is_fresh rejects a source past the timeout" {
  # Arrange
  local recorded=1000 now=1011

  # Act
  run reorder_is_fresh "${recorded}" "${now}" 10

  # Assert
  [[ "${status}" -eq 1 ]]
}

@test "reorder_is_fresh rejects a source from the future" {
  # Arrange
  local recorded=1011 now=1000

  # Act
  run reorder_is_fresh "${recorded}" "${now}" 10

  # Assert
  [[ "${status}" -eq 1 ]]
}

@test "reorder_is_fresh rejects a non-numeric activity" {
  # Arrange
  local recorded="@3" now=1000

  # Act
  run reorder_is_fresh "${recorded}" "${now}" 10

  # Assert
  [[ "${status}" -eq 1 ]]
}

@test "reorder_is_fresh rejects a non-numeric timeout" {
  # Arrange
  local timeout="soon"

  # Act
  run reorder_is_fresh 1000 1000 "${timeout}"

  # Assert
  [[ "${status}" -eq 1 ]]
}

@test "reorder_edge_position puts the first edge at zero" {
  # Arrange
  local count=5

  # Act
  run reorder_edge_position first "${count}" centre

  # Assert
  [[ "${output}" == "0" ]]
}

@test "reorder_edge_position puts the last edge at the end" {
  # Arrange
  local count=5

  # Act
  run reorder_edge_position last "${count}" centre

  # Assert
  [[ "${output}" == "4" ]]
}

@test "reorder_edge_position puts the trailing edge at the end of a left list" {
  # Arrange
  local count=5

  # Act
  run reorder_edge_position trailing "${count}" left

  # Assert
  [[ "${status}" -eq 0 && "${output}" == "4" ]]
}

@test "reorder_edge_position refuses the trailing edge of a centred list" {
  # Arrange
  local count=5

  # Act
  run reorder_edge_position trailing "${count}" centre

  # Assert
  [[ "${status}" -eq 1 && -z "${output}" ]]
}

@test "reorder_edge_position refuses an unknown edge" {
  # Arrange
  local count=5

  # Act
  run reorder_edge_position middle "${count}" left

  # Assert
  [[ "${status}" -eq 1 ]]
}

@test "reorder_quote_for_run_shell escapes single quotes and hashes" {
  # Arrange
  local path="/a b/it's #1/reorder.sh"

  # Act
  run reorder_quote_for_run_shell "${path}"

  # Assert
  [[ "${output}" == "'/a b/it'\\''s ##1/reorder.sh'" ]]
}

@test "reorder_quote_for_tmux_double escapes backslashes, double quotes and dollars" {
  # Arrange
  local command="bash '/a/it'\\''s \"x\" \$HOME/reorder.sh'"

  # Act
  run reorder_quote_for_tmux_double "${command}"

  # Assert
  [[ "${output}" == "bash '/a/it'\\\\''s \\\"x\\\" \\\$HOME/reorder.sh'" ]]
}

@test "reorder_moved_order inserts a window moved forward" {
  # Arrange
  local items=(a b c d)

  # Act
  run reorder_moved_order 0 2 "${items[@]}"

  # Assert
  [[ "${output}" == $'b\nc\na\nd' ]]
}

@test "reorder_moved_order inserts a window moved backward" {
  # Arrange
  local items=(a b c d)

  # Act
  run reorder_moved_order 3 1 "${items[@]}"

  # Assert
  [[ "${output}" == $'a\nd\nb\nc' ]]
}

@test "reorder_moved_order appends a window moved to the end" {
  # Arrange
  local items=(a b c d)

  # Act
  run reorder_moved_order 0 3 "${items[@]}"

  # Assert
  [[ "${output}" == $'b\nc\nd\na' ]]
}

@test "reorder_hit_format nests one span per tab" {
  # Arrange
  local spans=(@1:13 @2:14)

  # Act
  run reorder_hit_format 9 1 "${spans[@]}"

  # Assert
  [[ "${output}" == '#{?#{&&:#{e|>=:#{mouse_x},9},#{e|<:#{mouse_x},22}},@1,#{?#{&&:#{e|>=:#{mouse_x},23},#{e|<:#{mouse_x},37}},@2,}}' ]]
}

@test "reorder_hit_format prints an empty expression for no tabs" {
  # Arrange
  local start=9

  # Act
  run reorder_hit_format "${start}" 1

  # Assert
  [[ -z "${output}" ]]
}

@test "reorder_list_width adds a separator between tabs" {
  # Arrange
  local spans=(@1:13 @2:14 @3:8)

  # Act
  run reorder_list_width 1 "${spans[@]}"

  # Assert
  [[ "${output}" == "37" ]]
}

@test "reorder_list_width of one tab has no separator" {
  # Arrange
  local spans=(@1:13)

  # Act
  run reorder_list_width 3 "${spans[@]}"

  # Assert
  [[ "${output}" == "13" ]]
}
