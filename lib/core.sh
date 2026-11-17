#!/bin/sh
# shellcheck disable=SC2034

[ -n "${REORDER_REVAMPED_CORE_LOADED:-}" ] && return 0
REORDER_REVAMPED_CORE_LOADED=1

readonly REORDER_REVAMPED_VERSION="1.2.0"
