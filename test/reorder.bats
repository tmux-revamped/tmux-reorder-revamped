#!/usr/bin/env bats
# shellcheck disable=SC2016,SC2030,SC2031,SC2034

# shellcheck source=test/reorder_helpers.bash
source "${BATS_TEST_DIRNAME:-.}/reorder_helpers.bash"

@test "reorder - the version is read from tmux -V, next and patch builds included" {
  # Arrange
  local script='for v in "tmux 3.8" "tmux 3.5a" "tmux next-3.9" "tmux master"; do printf "[%s]" "$(reorder_revamped_parse_version "${v}")"; done'

  # Act
  lib_run reorder "${script}"

  # Assert
  [[ "${output}" == "[3.8][3.5][3.9][]" ]]
}

@test "reorder - version_ge compares major and minor numbers" {
  # Arrange
  local script='for p in "3.2 3.2" "3.10 3.2" "4.0 3.9" "3.1 3.2" "2.9 3.0" "x 3.2"; do set -- ${p}; if reorder_revamped_version_ge "$1" "$2"; then printf y; else printf n; fi; done'

  # Act
  lib_run reorder "${script}"

  # Assert
  [[ "${output}" == "yyynnn" ]]
}

@test "reorder - an unknown tmux version counts as new enough" {
  # Arrange
  local script='REORDER_REVAMPED_TMUX=""; reorder_revamped_at_least 9.9 && printf yes'

  # Act
  lib_run reorder "${script}"

  # Assert
  [[ "${output}" == "yes" ]]
}

@test "reorder - a drag is fresh only inside the timeout and with whole numbers" {
  # Arrange
  local script='for f in "1000 1005 10" "1000 1011 10" "1010 1000 10" "1000 soon 10" "1000 1005 x" "1000 1005 " " 1005 10"; do set -- ${f}; if reorder_revamped_is_fresh "${1:-}" "${2:-}" "${3:-}"; then printf y; else printf n; fi; done'

  # Act
  lib_run reorder "${script}"

  # Assert
  [[ "${output}" == "ynnnnnn" ]]
}

@test "reorder - an edge maps to the first or last position" {
  # Arrange
  local script='for e in "first 4 left" "last 4 left" "trailing 4 left" "trailing 4 centre" "middle 4 left"; do set -- ${e}; printf "[%s]" "$(reorder_revamped_edge_position "$1" "$2" "$3" || printf x)"; done'

  # Act
  lib_run reorder "${script}"

  # Assert
  [[ "${output}" == "[0][3][3][x][x]" ]]
}

@test "reorder - a path is quoted for run-shell with its quotes and hashes escaped" {
  # Arrange
  local script="reorder_revamped_quote_run_shell \"it's #1\""

  # Act
  lib_run reorder "${script}"

  # Assert
  [[ "${output}" == "'it'\\''s ##1'" ]]
}

@test "reorder - a command is escaped for a tmux double-quoted string" {
  # Arrange
  local script='reorder_revamped_quote_double "a\\b\"c\$d"'

  # Act
  lib_run reorder "${script}"

  # Assert
  [[ "${output}" == 'a\\b\"c\$d' ]]
}

@test "reorder - the tool path survives a quote in the checkout" {
  # Arrange
  export PROBE_LIB="/tmp/it's/lib"

  # Act
  lib_run reorder 'REVAMPED_LIB="${PROBE_LIB}"; reorder_revamped_tool'

  # Assert
  [[ "${output}" == "'/tmp/it'\\''s/bin/reorder-revamped'" ]]
}

@test "reorder - a window moved forward lands after the ones it passed" {
  # Arrange
  local script="${WINDOWS}"'reorder_revamped_moved 0 2 | awk "{ printf \"%s \", \$2 }"'

  # Act
  lib_run reorder "${script}"

  # Assert
  [[ "${output}" == "@2 @3 @1 @4 " ]]
}

@test "reorder - a window moved backward lands before the ones it passed" {
  # Arrange
  local script="${WINDOWS}"'reorder_revamped_moved 3 1 | awk "{ printf \"%s \", \$2 }"'

  # Act
  lib_run reorder "${script}"

  # Assert
  [[ "${output}" == "@1 @4 @2 @3 " ]]
}

@test "reorder - a window moved to the end is appended" {
  # Arrange
  local script="${WINDOWS}"'reorder_revamped_moved 0 3 | awk "{ printf \"%s \", \$2 }"'

  # Act
  lib_run reorder "${script}"

  # Assert
  [[ "${output}" == "@2 @3 @4 @1 " ]]
}

@test "reorder - the hit format maps each tab span after status-left to its window" {
  # Arrange
  export PROBE_LAYOUT="${LAYOUT}"

  # Act
  hit_for

  # Assert
  [[ "${output}" == "${HIT}" ]]
}

@test "reorder - the hit format caps status-left at its configured length" {
  # Arrange
  export PROBE_LAYOUT='left|on|200|120|100|30|100|1'

  # Act
  hit_for

  # Assert
  [[ "${output}" == *'#{e|>=:#{mouse_x},100},#{e|<:#{mouse_x},113}},@1,'* ]]
}

@test "reorder - the hit format maps nothing for a centred list, an overflow or two status lines" {
  # Arrange
  local script="${WINDOWS}"'for l in "centre|on|200|9|100|30|100|1" "left|on|60|9|100|30|100|1" "left|2|200|9|100|30|100|1"; do printf "[%s]" "$(reorder_revamped_hit "$l" "$REORDER_REVAMPED_WINDOWS")"; done; printf "[%s]" "$(reorder_revamped_hit "left|on|200|9|100|30|100|1" "")"'

  # Act
  lib_run reorder "${script}"

  # Assert
  [[ "${output}" == "[][][][]" ]]
}

@test "reorder - an insert walks the window through each neighbour by its real index" {
  # Arrange
  local script='REORDER_REVAMPED_WINDOWS=$(printf "%s\n" "1 @1 9" "3 @2 9" "5 @3 9"); reorder_revamped_swaps work @1 insert 0 2 | tr "\n" " "; printf "|"; reorder_revamped_swaps work @3 insert 2 0 | tr "\n" " "'

  # Act
  lib_run reorder "${script}"

  # Assert
  [[ "${output}" == "swap-window -d -s @1 -t work:3  swap-window -d -s @1 -t work:5  |swap-window -d -s @3 -t work:3  swap-window -d -s @3 -t work:1  " ]]
}

@test "reorder - a swap exchanges only the two windows" {
  # Arrange
  local script="${WINDOWS}"'reorder_revamped_swaps work @1 swap 0 2 | tr "\n" " "'

  # Act
  lib_run reorder "${script}"

  # Assert
  [[ "${output}" == "swap-window -d -s @1 -t work:3  " ]]
}
