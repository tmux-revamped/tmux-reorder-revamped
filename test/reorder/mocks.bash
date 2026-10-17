#!/usr/bin/env bash

load "${BATS_TEST_DIRNAME}/../helpers.bash"

setup_reorder_mocks() {
  setup_test_environment
  export REORDER_DRY_RUN=1
  source "${BATS_TEST_DIRNAME}/../../src/reorder.sh"
  MOCK_SETTINGS="||left"
  MOCK_LAYOUT="left|on|200|9|100|30|100|1"
  MOCK_WINDOWS=$'1 @1 13\n2 @2 14\n3 @3 14\n4 @4 8'
  MOCK_OPTIONS=()
  MOCK_KEYS=""
  MOCK_VERSION="tmux 3.8"
  _query() { mock_query "$@"; }
  _tmux_version_string() { printf '%s\n' "${MOCK_VERSION}"; }
}

mock_option() {
  local name="${1}" entry
  for entry in "${MOCK_OPTIONS[@]}"; do
    [[ "${entry%%=*}" == "${name}" ]] && printf '%s\n' "${entry#*=}"
  done
  return 0
}

mock_query() {
  case "${1}" in
    display-message)
      if [[ "$*" == *"status-left"* ]]; then
        printf '%s\n' "${MOCK_LAYOUT}"
      else
        printf '%s\n' "${MOCK_SETTINGS}"
      fi
      ;;
    list-windows) printf '%s\n' "${MOCK_WINDOWS}" ;;
    show-option) mock_option "${3}" ;;
    list-keys) if [[ $# -eq 1 ]]; then printf '%s\n' "${MOCK_KEYS}"; fi ;;
  esac
}
