# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.1] - 2026-10-27

### Fixed

- The plugin loads under TPM. Its entry point was committed without the
  executable bit, and TPM runs an entry point as a program and discards its
  errors, so no binding was ever installed.
- Tabs slide while dragged when the plugin directory path contains a single
  quote, a double quote, a dollar sign or a backslash.
- On tmux 3.7 to 3.7c, clicking a tab switches to that window again. Those
  versions print a single `list-keys` match to the status line instead of
  returning it, so the stock click binding was lost when the plugin wrapped it.

## [1.0.0] - 2026-10-16

### Added

- Drag a window tab along the status bar and it slides into each tab it
  crosses while the button is held, the way browser tabs move; release it
  where you see it.
- Releasing over `status-left` moves the window first; releasing over
  `status-right`, or over empty space after a left-justified window list,
  moves it last. `@reorder_revamped_edges off` turns these off.
- `@reorder_revamped_mode swap` exchanges only the two windows, on release.
- `@reorder_revamped_live off` keeps the tabs still until release.
- A drag counts only when it began with a press on a tab, so a text selection
  in a pane that runs across the bar moves nothing. The stock
  `MouseDown1Status` command keeps running.
- Works on tmux 3.2 and later; tmux below 3.2 binds nothing.
