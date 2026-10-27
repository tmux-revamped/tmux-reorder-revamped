#!/usr/bin/env bash
# shellcheck disable=SC2034

[[ -n "${_TMUX_PLUGIN_CONSTANTS_LOADED:-}" ]] && return 0
_TMUX_PLUGIN_CONSTANTS_LOADED=1

readonly REORDER_REVAMPED_VERSION="1.0.1"
readonly REORDER_MIN_TMUX="3.2"
readonly REORDER_LIVE_MIN_TMUX="3.8"
readonly REORDER_SOURCE_OPTION="@reorder_revamped_source"
readonly REORDER_SEEN_OPTION="@reorder_revamped_seen"
readonly REORDER_PRESS_OPTION="@reorder_revamped_pressed"
readonly REORDER_PRESS_AT_OPTION="@reorder_revamped_pressed_at"
readonly REORDER_PRESS_ORIGINAL_OPTION="@reorder_revamped_press_original"
readonly REORDER_HIT_OPTION="@reorder_revamped_hit"
readonly REORDER_PROBE_OPTION="@reorder_revamped_probe"
readonly REORDER_HOVER_OPTION="@reorder_revamped_hover"
readonly REORDER_MODE_OPTION="@reorder_revamped_mode"
readonly REORDER_TIMEOUT_OPTION="@reorder_revamped_timeout"
readonly REORDER_EDGES_OPTION="@reorder_revamped_edges"
readonly REORDER_LIVE_OPTION="@reorder_revamped_live"
readonly REORDER_MODE_INSERT="insert"
readonly REORDER_MODE_SWAP="swap"
readonly REORDER_DEFAULT_TIMEOUT="10"
readonly REORDER_DRAG_GAP_SECONDS="2"
readonly REORDER_PRESS_WINDOW_SECONDS="10"
readonly REORDER_SWITCH_ON="on"
readonly REORDER_EDGE_FIRST="first"
readonly REORDER_EDGE_LAST="last"
readonly REORDER_EDGE_TRAILING="trailing"
readonly REORDER_JUSTIFY_LEFT="left"
readonly REORDER_STATUS_SINGLE_LINE="on"
readonly REORDER_FIELD_SEPARATOR="|"
readonly REORDER_WINDOW_HIT_FORMAT="#{window_id}"
