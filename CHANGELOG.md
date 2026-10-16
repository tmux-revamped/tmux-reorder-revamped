# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-10-16

### Added

- Drag a window tab on the status bar and release it over another tab to move
  the window there; the windows in between shift over.
- Releasing over `status-left` moves the window first; releasing over
  `status-right`, or over empty space after a left-justified window list,
  moves it last. `@reorder_revamped_edges off` turns these off.
- `@reorder_revamped_mode swap` exchanges only the two windows.
- `@reorder_revamped_timeout` ignores a drag abandoned over a pane, so a later
  text selection released on the bar cannot move a window.
- tmux below 3.2 binds nothing.
