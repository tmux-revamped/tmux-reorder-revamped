#!/usr/bin/env bats
# shellcheck disable=SC2034

load "${BATS_TEST_DIRNAME}/mocks.bash"

setup() {
  setup_reorder_mocks
}

teardown() {
  cleanup_test_environment
}

@test "drop falls back to the default timeout when the option is not a number" {
  # Arrange
  MOCK_SETTINGS="|soon|left"

  # Act
  run reorder_drop work "@1:1000" @2 1010

  # Assert
  [[ "${output}" == 'tmux swap-window -d -s @1 -t work:2 ; select-window -t @1' ]]
}

@test "drop forward walks the window through each neighbour" {
  # Arrange
  local source="@1:1000"

  # Act
  run reorder_drop work "${source}" @3 1000

  # Assert
  [[ "${output}" == 'tmux swap-window -d -s @1 -t work:2 ; swap-window -d -s @1 -t work:3 ; select-window -t @1' ]]
}

@test "drop backward walks the window toward the start" {
  # Arrange
  local source="@4:1000"

  # Act
  run reorder_drop work "${source}" @2 1000

  # Assert
  [[ "${output}" == 'tmux swap-window -d -s @4 -t work:3 ; swap-window -d -s @4 -t work:2 ; select-window -t @4' ]]
}

@test "drop keeps index gaps by targeting real indices" {
  # Arrange
  MOCK_WINDOWS=$'1 @1\n5 @2\n9 @3'

  # Act
  run reorder_drop work "@1:1000" @3 1000

  # Assert
  [[ "${output}" == 'tmux swap-window -d -s @1 -t work:5 ; swap-window -d -s @1 -t work:9 ; select-window -t @1' ]]
}

@test "drop in swap mode exchanges only the two windows" {
  # Arrange
  MOCK_SETTINGS="swap||left"

  # Act
  run reorder_drop work "@1:1000" @3 1000

  # Assert
  [[ "${output}" == 'tmux swap-window -d -s @1 -t work:3 ; select-window -t @1' ]]
}

@test "drop does nothing without a recorded source" {
  # Arrange
  local source=""

  # Act
  run reorder_drop work "${source}" @3 1000

  # Assert
  [[ "${status}" -eq 0 && -z "${output}" ]]
}

@test "drop does nothing when released on the grabbed tab" {
  # Arrange
  local source="@3:1000"

  # Act
  run reorder_drop work "${source}" @3 1000

  # Assert
  [[ "${status}" -eq 0 && -z "${output}" ]]
}

@test "drop ignores a source older than the default timeout" {
  # Arrange
  local source="@1:1000"

  # Act
  run reorder_drop work "${source}" @3 1011

  # Assert
  [[ "${status}" -eq 0 && -z "${output}" ]]
}

@test "drop honours a configured timeout" {
  # Arrange
  MOCK_SETTINGS="|30|left"

  # Act
  run reorder_drop work "@1:1000" @2 1025

  # Assert
  [[ "${output}" == 'tmux swap-window -d -s @1 -t work:2 ; select-window -t @1' ]]
}

@test "drop does nothing when the grabbed window has closed" {
  # Arrange
  MOCK_WINDOWS=$'2 @2\n3 @3'

  # Act
  run reorder_drop work "@1:1000" @3 1000

  # Assert
  [[ "${status}" -eq 0 && -z "${output}" ]]
}

@test "drop does nothing when the target window has closed" {
  # Arrange
  MOCK_WINDOWS=$'1 @1\n2 @2'

  # Act
  run reorder_drop work "@1:1000" @3 1000

  # Assert
  [[ "${status}" -eq 0 && -z "${output}" ]]
}

@test "edge first moves the window to the start" {
  # Arrange
  local source="@3:1000"

  # Act
  run reorder_edge first work "${source}" 1000

  # Assert
  [[ "${output}" == 'tmux swap-window -d -s @3 -t work:2 ; swap-window -d -s @3 -t work:1 ; select-window -t @3' ]]
}

@test "edge last moves the window to the end" {
  # Arrange
  local source="@2:1000"

  # Act
  run reorder_edge last work "${source}" 1000

  # Assert
  [[ "${output}" == 'tmux swap-window -d -s @2 -t work:3 ; swap-window -d -s @2 -t work:4 ; select-window -t @2' ]]
}

@test "edge trailing does nothing for a centred window list" {
  # Arrange
  MOCK_SETTINGS="||centre"

  # Act
  run reorder_edge trailing work "@2:1000" 1000

  # Assert
  [[ "${status}" -eq 0 && -z "${output}" ]]
}

@test "edge does nothing when the window is already at the edge" {
  # Arrange
  local source="@1:1000"

  # Act
  run reorder_edge first work "${source}" 1000

  # Assert
  [[ "${status}" -eq 0 && -z "${output}" ]]
}

@test "a failed move is logged with the window and positions" {
  # Arrange
  _tmux() { return 1; }
  log_error() { printf 'logged %s: %s\n' "${1}" "${2}"; }

  # Act
  run reorder_drop work "@1:1000" @2 1000

  # Assert
  [[ "${output}" == 'logged reorder: moving @1 in work from position 0 to 1 failed' ]]
}

@test "grab maps each tab span after status-left to its window" {
  # Arrange
  local expected='tmux set-option -g @reorder_revamped_hit #{?#{&&:#{e|>=:#{mouse_x},9},#{e|<:#{mouse_x},22}},@1,#{?#{&&:#{e|>=:#{mouse_x},23},#{e|<:#{mouse_x},37}},@2,#{?#{&&:#{e|>=:#{mouse_x},38},#{e|<:#{mouse_x},52}},@3,#{?#{&&:#{e|>=:#{mouse_x},53},#{e|<:#{mouse_x},61}},@4,}}}}'

  # Act
  run reorder_grab work /dev/ttys000

  # Assert
  [[ "${output}" == "${expected}" ]]
}

@test "grab caps status-left at its configured length" {
  # Arrange
  MOCK_LAYOUT="left|on|200|120|100|30|100|1"

  # Act
  run reorder_grab work /dev/ttys000

  # Assert
  [[ "${output}" == *'#{e|>=:#{mouse_x},100},#{e|<:#{mouse_x},113}},@1,'* ]]
}

@test "grab maps nothing for a centred window list" {
  # Arrange
  MOCK_LAYOUT="centre|on|200|9|100|30|100|1"

  # Act
  run reorder_grab work /dev/ttys000

  # Assert
  [[ "${output}" == "tmux set-option -g @reorder_revamped_hit " ]]
}

@test "grab maps nothing when the window list overflows the bar" {
  # Arrange
  MOCK_LAYOUT="left|on|60|9|100|30|100|1"

  # Act
  run reorder_grab work /dev/ttys000

  # Assert
  [[ "${output}" == "tmux set-option -g @reorder_revamped_hit " ]]
}

@test "grab maps nothing for a multi-line status" {
  # Arrange
  MOCK_LAYOUT="left|2|200|9|100|30|100|1"

  # Act
  run reorder_grab work /dev/ttys000

  # Assert
  [[ "${output}" == "tmux set-option -g @reorder_revamped_hit " ]]
}

@test "slide moves the grabbed window onto the hovered tab" {
  # Arrange
  local source=@1 target=@3

  # Act
  run reorder_slide work "${source}" "${target}" "" 0

  # Assert
  [[ "${output}" == 'tmux swap-window -d -s @1 -t work:2 ; swap-window -d -s @1 -t work:3 ; select-window -t @1' ]]
}

@test "slide remaps the tab spans for the new order in the same command" {
  # Arrange
  local expected='tmux swap-window -d -s @1 -t work:2 ; swap-window -d -s @1 -t work:3 ; select-window -t @1 ; set-option -g @reorder_revamped_hit #{?#{&&:#{e|>=:#{mouse_x},9},#{e|<:#{mouse_x},23}},@2,#{?#{&&:#{e|>=:#{mouse_x},24},#{e|<:#{mouse_x},38}},@3,#{?#{&&:#{e|>=:#{mouse_x},39},#{e|<:#{mouse_x},52}},@1,#{?#{&&:#{e|>=:#{mouse_x},53},#{e|<:#{mouse_x},61}},@4,}}}}'

  # Act
  run reorder_slide work @1 @3 /dev/ttys000 1

  # Assert
  [[ "${output}" == "${expected}" ]]
}

@test "slide does nothing while the pointer stays on the grabbed tab" {
  # Arrange
  local source=@2

  # Act
  run reorder_slide work "${source}" @2 "" 1

  # Assert
  [[ "${status}" -eq 0 && -z "${output}" ]]
}

@test "slide does nothing when the pointer is off every tab" {
  # Arrange
  local target=""

  # Act
  run reorder_slide work @2 "${target}" "" 1

  # Assert
  [[ "${status}" -eq 0 && -z "${output}" ]]
}

@test "slide does nothing when the hovered window has closed" {
  # Arrange
  MOCK_WINDOWS=$'1 @1 13\n2 @2 14'

  # Act
  run reorder_slide work @1 @3 "" 1

  # Assert
  [[ "${status}" -eq 0 && -z "${output}" ]]
}

@test "slide does nothing when the grabbed window has closed" {
  # Arrange
  MOCK_WINDOWS=$'2 @2 14\n3 @3 14'

  # Act
  run reorder_slide work @1 @3 "" 1

  # Assert
  [[ "${status}" -eq 0 && -z "${output}" ]]
}
