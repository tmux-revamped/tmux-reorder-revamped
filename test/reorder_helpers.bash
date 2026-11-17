#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2030,SC2031,SC2034

# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

WINDOWS='REORDER_REVAMPED_WINDOWS=$(printf "%s\n" "1 @1 13" "2 @2 14" "3 @3 14" "4 @4 8"); '
LAYOUT='left|on|200|9|100|30|100|1'
HIT='#{?#{&&:#{e|>=:#{mouse_x},9},#{e|<:#{mouse_x},22}},@1,#{?#{&&:#{e|>=:#{mouse_x},23},#{e|<:#{mouse_x},37}},@2,#{?#{&&:#{e|>=:#{mouse_x},38},#{e|<:#{mouse_x},52}},@3,#{?#{&&:#{e|>=:#{mouse_x},53},#{e|<:#{mouse_x},61}},@4,}}}}'

setup() {
  harness_setup
  for name in $(compgen -v REORDER_REVAMPED_); do
    unset "${name}"
  done
}

option() {
  printf '%s' "$2" >"${REVAMPED_TEST_TMUX_DIR}/$(printf '%s' "g.-.@reorder_revamped_$1" | tr -c 'A-Za-z0-9_.-' '_')"
}

plan_at() {
  export REVAMPED_TEST_TMUX_VERSION="$1"
  lib_run reorder 'reorder_revamped_plan; reorder_revamped_lines'
}

hit_for() {
  lib_run reorder "${WINDOWS}"'reorder_revamped_hit "$PROBE_LAYOUT" "$REORDER_REVAMPED_WINDOWS"'
}

refuse() {
  mkdir -p "${BATS_TEST_TMPDIR}/stubs"
  printf '#!/bin/sh\nfor a in "$@"; do [ "$a" != ";" ] || exit 1; [ "$a" != BAD ] || { printf "unknown key: BAD\\n" >&2; exit 1; }; done\nexec "%s/bin/tmux" "$@"\n' "${REVAMPED_TESTS_DIR}" >"${BATS_TEST_TMPDIR}/stubs/tmux"
  chmod +x "${BATS_TEST_TMPDIR}/stubs/tmux"
}

keys() {
  mkdir -p "${BATS_TEST_TMPDIR}/stubs"
  printf '%s\n' "$@" >"${BATS_TEST_TMPDIR}/keys"
  printf '#!/bin/sh\nif [ "$1" = list-keys ]; then cat "%s"; exit 0; fi\nexec "%s/bin/tmux" "$@"\n' "${BATS_TEST_TMPDIR}/keys" "${REVAMPED_TESTS_DIR}" >"${BATS_TEST_TMPDIR}/stubs/tmux"
  chmod +x "${BATS_TEST_TMPDIR}/stubs/tmux"
}
