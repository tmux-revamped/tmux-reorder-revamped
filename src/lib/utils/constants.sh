#!/usr/bin/env bash
# shellcheck disable=SC2034

[[ -n "${_TMUX_PLUGIN_CONSTANTS_LOADED:-}" ]] && return 0
_TMUX_PLUGIN_CONSTANTS_LOADED=1

readonly REORDER_REVAMPED_VERSION="1.0.0"
readonly REORDER_MIN_TMUX="3.2"
readonly REORDER_SOURCE_OPTION="@reorder_revamped_source"
readonly REORDER_MODE_OPTION="@reorder_revamped_mode"
readonly REORDER_TIMEOUT_OPTION="@reorder_revamped_timeout"
readonly REORDER_EDGES_OPTION="@reorder_revamped_edges"
readonly REORDER_MODE_INSERT="insert"
readonly REORDER_MODE_SWAP="swap"
readonly REORDER_DEFAULT_TIMEOUT="10"
readonly REORDER_EDGES_ON="on"
readonly REORDER_EDGE_FIRST="first"
readonly REORDER_EDGE_LAST="last"
readonly REORDER_EDGE_TRAILING="trailing"
readonly REORDER_JUSTIFY_LEFT="left"
readonly REORDER_FIELD_SEPARATOR="|"
