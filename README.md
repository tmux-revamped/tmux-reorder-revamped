# tmux-reorder-revamped

**Drag a window tab on the status bar with the mouse to move that window.**

[![Tests](https://github.com/tmux-revamped/tmux-reorder-revamped/actions/workflows/tests.yml/badge.svg)](https://github.com/tmux-revamped/tmux-reorder-revamped/actions/workflows/tests.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) [![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](CHANGELOG.md)

Press a tab and drag it along the bar. The tab travels with the pointer: each time the pointer enters another tab, the grabbed one takes its place and the others shift aside, the way browser tabs and desktop icons behave. Release it where you see it. Release over `status-left` to make it the first window, or past the last tab to make it the last. Plain tmux, no patch, no polling: the motion check runs inside tmux, and a short script runs only when the tab crosses into another one.

Built from [tmux-plugin-template](https://github.com/tmux-revamped/tmux-plugin-template).

## Requirements

- tmux 3.2 or later. On an older tmux the plugin binds nothing.
- `set -g mouse on`.
- bash 3.2 or later.

## Installation

With [TPM](https://github.com/tmux-plugins/tpm):

```tmux
set -g mouse on
set -g @plugin 'tmux-revamped/tmux-reorder-revamped'
```

Press `prefix + I` to install.

Manually:

```sh
git clone https://github.com/tmux-revamped/tmux-reorder-revamped ~/.tmux/plugins/tmux-reorder-revamped
```

Then add `run-shell ~/.tmux/plugins/tmux-reorder-revamped/reorder-revamped.tmux` to `~/.tmux.conf` and reload.

## Usage

| Gesture | Result |
|---|---|
| Drag a tab over another tab | The grabbed tab slides into that position while you hold the button |
| Release over another tab | The window stays where it slid to |
| Release over `status-left` | The window becomes the first window |
| Release over `status-right` | The window becomes the last window |
| Release over empty space after the last tab | The window becomes the last window, when `status-justify` is `left` |
| Release over the tab you grabbed | Nothing moves |

The dragged window stays the current window. Window indices keep their gaps: the windows trade places, and no index is renumbered.

## Configuration

| Option | Default | Description |
|---|---|---|
| `@reorder_revamped_mode` | `insert` | `insert` moves the window and shifts the ones in between. `swap` exchanges only the two windows, on release, with no live slide |
| `@reorder_revamped_live` | `on` | `off` keeps the tabs still while you drag and moves the window only on release |
| `@reorder_revamped_edges` | `on` | `off` leaves `status-left`, `status-right` and empty space unbound |
| `@reorder_revamped_timeout` | `10` | Seconds of client activity after which a recorded drag is ignored. A drag you abandon over a pane cannot then move a window on a later, unrelated release |
| `@reorder_revamped_enable_logging` | unset | `1` writes failed moves to `~/.tmux/reorder-revamped-logs/` |
| `@reorder_revamped_source` | managed | Internal. The grabbed window while a drag is in progress |
| `@reorder_revamped_seen` | managed | Internal. Client activity at the latest motion of the drag |
| `@reorder_revamped_hit` | managed | Internal. A format that maps the pointer column to the tab under it |
| `@reorder_revamped_probe` | managed | Internal. The tab under the pointer at the latest motion |
| `@reorder_revamped_hover` | managed | Internal. The tab the grabbed one last slid onto |
| `@reorder_revamped_pressed` | managed | Internal. The tab under the latest press on the status bar |
| `@reorder_revamped_pressed_at` | managed | Internal. Client activity at that press |
| `@reorder_revamped_press_original` | managed | Internal. The `MouseDown1Status` command the plugin wraps |

Mode, live and edges are read when the plugin loads; reload the config after changing them.

```tmux
set -g @reorder_revamped_mode 'swap'
set -g @reorder_revamped_edges 'off'
```

## Key bindings

All of them live in the root table, because a mouse gesture has no prefix. `MouseDown1Status` is the only stock tmux binding involved, and the plugin wraps it rather than replacing it: the original command, `switch-client -t =` by default, still runs after the press is recorded, and is saved in `@reorder_revamped_press_original` so a reload never wraps it twice.

| Key | Action |
|---|---|
| `MouseDown1Status` | Records the tab you pressed, then runs the original press command |
| `SecondClick1Status`, `TripleClick1Status` | Record the press too, because tmux reports a press soon after a click as a repeated click. Left alone if you bound them yourself |
| `MouseUp1Status` | Forgets the press on a plain click. Left alone if you bound it yourself |
| `MouseDrag1Status` | Records the grabbed tab on the first motion, then slides it whenever the pointer enters another tab |
| `MouseDragEnd1Status` | Moves the grabbed window to the tab under the pointer |
| `MouseDragEnd1StatusLeft` | Moves it first, when edges are on |
| `MouseDragEnd1StatusRight` | Moves it last, when edges are on |
| `MouseDragEnd1StatusDefault` | Moves it last when the window list is left-justified, when edges are on |

A press on a tab still selects the window through tmux's own `MouseDown1Status`.

## How it works

The first motion of a drag names the tab you pressed, and the plugin stores it in a server option with `set-option -F`, which starts no process. On tmux 3.8 and later, tmux keeps reporting that same tab for the whole drag but tracks the real pointer column in `mouse_x`. So when a drag starts, `src/reorder.sh grab` measures every tab with tmux's own `#{w:}` width modifier, the same arithmetic the status line uses, and stores a format that turns `mouse_x` into the tab under the pointer. Each motion evaluates that format inside tmux. On tmux 3.2 to 3.7, tmux reports the tab under the pointer directly, so no measuring is needed.

Only when the pointer enters a different tab does the plugin run `src/reorder.sh slide`, which moves the grabbed window with one tmux command made of adjacent `swap-window -d` steps and remeasures the tabs in the same command. Live measuring needs a left-justified, single-line status bar whose window list fits; otherwise the window moves on release only.

A drag only counts when it began with a press on a tab within the last 10 seconds. A drag that starts inside a pane, such as a text selection in vim, never pressed a tab, so crossing or releasing over the bar moves nothing.

## Development

| Command | Description |
|---|---|
| `make test` | Run the bats suite |
| `make lint` | Run shellcheck at warning severity |
| `make coverage` | Measure line coverage with kcov and enforce the floor, on Linux |

The integration tests start their own tmux servers on private sockets with an empty config. The mouse tests attach a client of one test server inside a second one and type SGR mouse sequences into it.

## License

[MIT](LICENSE)

<!-- family:begin -->

## The tmux-revamped family

This plugin is one member of the tmux-revamped family. Every member carries the
same contract in [`FAMILY.md`](FAMILY.md), the same tooling under `family/`, and
the same shared library, all held byte-identical by a checksum manifest. They are
built to be installed together: no member claims a key or a tmux option that
another member claims.

A defect found in one member is hunted across all of them before the fix is
called done. That obligation is written into the contract rather than left to
memory, and `family/bin/sweep` is how it is discharged.

| Member | What it does |
|---|---|
| [`tmux-autoreload-revamped`](https://github.com/tmux-revamped/tmux-autoreload-revamped) | Edit your tmux config, save, and watch it reload itself, no key, no command |
| [`tmux-battery-revamped`](https://github.com/tmux-revamped/tmux-battery-revamped) | Battery status for your tmux status bar, without ever blocking the status render |
| [`tmux-bluetooth-revamped`](https://github.com/tmux-revamped/tmux-bluetooth-revamped) | Every connected Bluetooth device and its battery in your tmux status bar, without blocking the render |
| [`tmux-cpu-revamped`](https://github.com/tmux-revamped/tmux-cpu-revamped) | CPU load, temperature, and frequency in your tmux status bar, without ever blocking the render |
| [`tmux-disk-revamped`](https://github.com/tmux-revamped/tmux-disk-revamped) | Disk usage for your tmux status bar, without ever blocking the status render |
| [`tmux-extract-revamped`](https://github.com/tmux-revamped/tmux-extract-revamped) | Fuzzy-grab any URL, path, or word off the screen and paste it, pure shell, no Python |
| [`tmux-fzf-revamped`](https://github.com/tmux-revamped/tmux-fzf-revamped) | Jump to any session, window, or pane, or kill it, from one fzf popup |
| [`tmux-git-revamped`](https://github.com/tmux-revamped/tmux-git-revamped) | Git repository status in your tmux status bar, without ever blocking the render |
| [`tmux-gpu-revamped`](https://github.com/tmux-revamped/tmux-gpu-revamped) | GPU load, temperature, frequency, and memory for your tmux status bar |
| [`tmux-kube-revamped`](https://github.com/tmux-revamped/tmux-kube-revamped) | Current Kubernetes context and namespace in your tmux status bar, async, kubectl-free, never blocking |
| [`tmux-launcher-revamped`](https://github.com/tmux-revamped/tmux-launcher-revamped) | Launch any TUI app in a popup or a window, scoped to the current pane's directory, with one configurable bindi |
| [`tmux-logging-revamped`](https://github.com/tmux-revamped/tmux-logging-revamped) | Capture any pane to a file: live logging, full scrollback, or a one-shot screenshot |
| [`tmux-music-revamped`](https://github.com/tmux-revamped/tmux-music-revamped) | Now playing in your tmux status bar, without ever blocking the status render |
| [`tmux-network-revamped`](https://github.com/tmux-revamped/tmux-network-revamped) | Network throughput in your tmux status bar, without ever blocking the render |
| [`tmux-pain-control-revamped`](https://github.com/tmux-revamped/tmux-pain-control-revamped) | Standard pane and window management bindings for tmux, version aware, vim friendly, and fully configurable |
| [`tmux-persist-revamped`](https://github.com/tmux-revamped/tmux-persist-revamped) | Save, auto-save, and restore your whole tmux environment, one plugin, no status-line tricks |
| [`tmux-plugin-template`](https://github.com/tmux-revamped/tmux-plugin-template) | A template for building non-blocking tmux status plugins |
| [`tmux-pomodoro-revamped`](https://github.com/tmux-revamped/tmux-pomodoro-revamped) | A Pomodoro timer in your tmux status bar, with zero temp files: all state lives in tmux options |
| [`tmux-ram-revamped`](https://github.com/tmux-revamped/tmux-ram-revamped) | RAM usage for your tmux status bar, without ever blocking the status render |
| [`tmux-reorder-revamped`](https://github.com/tmux-revamped/tmux-reorder-revamped) | **this plugin**, Drag a window tab on the status bar with the mouse to move that window |
| [`tmux-scroll-revamped`](https://github.com/tmux-revamped/tmux-scroll-revamped) | Mouse wheel that does the right thing: scroll the app directly, copy-mode everywhere else. No app names to con |
| [`tmux-sensible-revamped`](https://github.com/tmux-revamped/tmux-sensible-revamped) | Sensible tmux defaults that normalize behavior across every tmux version, OS, and terminal, without clobbering |
| [`tmux-tiling-revamped`](https://github.com/tmux-revamped/tmux-tiling-revamped) | BSP tiling window management for tmux. Eight layouts, nineteen operations, zero dependencies |
| [`tmux-time-revamped`](https://github.com/tmux-revamped/tmux-time-revamped) | Local clock and world clocks in your tmux status bar, without ever blocking the render |
| [`tmux-weather-revamped`](https://github.com/tmux-revamped/tmux-weather-revamped) | Weather in your tmux status bar, fetched in the background so the render never waits on the network |

### Checking an installation

With every member on disk, one command reports any conflict between them:

```sh
family/bin/doctor --live
```

It reads each member and the running tmux server, and reports duplicate keys,
duplicate status placeholders, options outside the naming grammar, and any
member whose contract version has fallen behind.

<!-- family:end -->
