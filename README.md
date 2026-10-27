<div align="center">

# tmux-reorder-revamped

<strong>Drag a window tab along the tmux status bar with the mouse to move that window.</strong>

English | [日本語](README.ja.md) | [简体中文](README.zh-Hans.md) | [繁體中文（香港）](README.zh-HK.md)

[![Tests](https://github.com/tmux-revamped/tmux-reorder-revamped/actions/workflows/tests.yml/badge.svg)](https://github.com/tmux-revamped/tmux-reorder-revamped/actions/workflows/tests.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.1-blue.svg)](CHANGELOG.md)

<p align="center">
  <a href="#what-it-does">What it does</a> |
  <a href="#installation">Installation</a> |
  <a href="#usage">Usage</a> |
  <a href="#configuration">Configuration</a> |
  <a href="#key-bindings">Key bindings</a> |
  <a href="#how-it-works">How it works</a>
</p>

</div>

**9 root-table mouse bindings. No polling. One tmux command per slide. Tested on macOS and Linux.**

---

## What it does

Press a tab and drag it along the bar. The tab travels with the pointer: each time the pointer enters another tab, the grabbed one takes its place and the others shift aside, the way browser tabs behave. Release it where you see it. Release over `status-left` to make it the first window, or past the last tab to make it the last.

It is plain tmux, with no patch and no polling. The motion check runs inside tmux, and a short script runs only when the tab crosses into another one.

## Requirements

| Requirement | Version or note |
|:------------|:----------------|
| tmux | 3.2 or later. On an older tmux the plugin binds nothing. Tabs slide under the pointer on every supported version, with a measured hit test on 3.8 and later |
| Mouse | `set -g mouse on` |
| bash | 3.2 or later, so the stock macOS `/bin/bash` works |
| Operating system | macOS on Apple Silicon and Intel, Linux on x86_64 and arm64 |
| Core tools | BSD, GNU or uutils coreutils |

## Installation

With [TPM](https://github.com/tmux-plugins/tpm), add the plugin to `~/.tmux.conf` and press `prefix + I`:

```tmux
set -g mouse on
set -g @plugin 'tmux-revamped/tmux-reorder-revamped'
```

Without TPM, clone the repository and run the entry point from `~/.tmux.conf`:

```sh
git clone https://github.com/tmux-revamped/tmux-reorder-revamped ~/.tmux/plugins/tmux-reorder-revamped
```

```tmux
run-shell ~/.tmux/plugins/tmux-reorder-revamped/reorder-revamped.tmux
```

## Usage

| Gesture | Result |
|:--------|:-------|
| Drag a tab over another tab | The grabbed tab slides into that position while you hold the button |
| Release over another tab | The window stays where it slid to |
| Release over `status-left` | The window becomes the first window |
| Release over `status-right` | The window becomes the last window |
| Release over empty space after the last tab | The window becomes the last window, when `status-justify` is `left` |
| Release over the tab you grabbed | Nothing moves |

The dragged window stays the current window. Window indexes keep their gaps: the windows trade places, and no index is renumbered.

## Configuration

Set any option in `~/.tmux.conf` before the plugin loads. Mode, live and edges are read at load time, so reload the config after changing them.

| Option | Default | Meaning |
|:-------|:--------|:--------|
| `@reorder_revamped_mode` | `insert` | `insert` moves the window and shifts the ones in between. `swap` exchanges only the two windows, on release, with no live slide |
| `@reorder_revamped_live` | `on` | `off` keeps the tabs still while you drag and moves the window only on release |
| `@reorder_revamped_edges` | `on` | `off` leaves `status-left`, `status-right` and the empty space unbound |
| `@reorder_revamped_timeout` | `10` | Seconds of client activity after which a recorded drag is ignored, so a drag abandoned over a pane cannot move a window on a later release |
| `@reorder_revamped_enable_logging` | unset | `1` writes failed moves to `~/.tmux/reorder-revamped-logs/` |

```tmux
set -g @reorder_revamped_mode 'swap'
set -g @reorder_revamped_edges 'off'
```

### Internal state

The plugin manages these options itself. Do not set them.

| Option | Holds |
|:-------|:------|
| `@reorder_revamped_source` | The grabbed window while a drag is in progress |
| `@reorder_revamped_seen` | Client activity at the latest motion of the drag |
| `@reorder_revamped_hit` | A format that maps the pointer column to the tab under it |
| `@reorder_revamped_probe` | The tab under the pointer at the latest motion |
| `@reorder_revamped_hover` | The tab the grabbed one last slid onto |
| `@reorder_revamped_pressed` | The tab under the latest press on the status bar |
| `@reorder_revamped_pressed_at` | Client activity at that press |
| `@reorder_revamped_press_original` | The `MouseDown1Status` command the plugin wraps |

## Key bindings

All bindings live in the root table, because a mouse gesture has no prefix. The plugin binds no prefix key.

| Key | Action |
|:----|:-------|
| `MouseDown1Status` | Records the tab you pressed, then runs the original press command |
| `SecondClick1Status`, `TripleClick1Status` | Record the press too, because tmux reports a press soon after a click as a repeated click. Left alone when you bound them yourself |
| `MouseUp1Status` | Forgets the press on a plain click. Left alone when you bound it yourself |
| `MouseDrag1Status` | Records the grabbed tab on the first motion, then slides it whenever the pointer enters another tab |
| `MouseDragEnd1Status` | Moves the grabbed window to the tab under the pointer |
| `MouseDragEnd1StatusLeft` | Moves it first, when edges are on |
| `MouseDragEnd1StatusRight` | Moves it last, when edges are on |
| `MouseDragEnd1StatusDefault` | Moves it last when the window list is left-justified, when edges are on |

`MouseDown1Status` is the only stock binding involved, and the plugin wraps it rather than replacing it. The original command, `switch-client -t =` by default, still runs after the press is recorded, so a press on a tab still selects the window. The original is saved in `@reorder_revamped_press_original`, so a reload never wraps it twice.

## How it works

**Grabbing.** The first motion of a drag names the tab you pressed, and the plugin stores it in a server option with `set-option -F`, which starts no process.

**Finding the tab under the pointer.** On tmux 3.2 to 3.7, tmux reports the tab under the pointer directly. On tmux 3.8 and later, it keeps reporting the tab where the drag started and tracks the real column in `mouse_x`. So when a drag starts there, `src/reorder.sh grab` measures every tab with tmux's own `#{w:}` width modifier, the arithmetic the status line itself uses, and stores a format that turns `mouse_x` into the tab under the pointer. Each motion evaluates that format inside tmux.

**Sliding.** Only when the pointer enters a different tab does the plugin run `src/reorder.sh slide`. It moves the grabbed window with one tmux command made of adjacent `swap-window -d` steps and remeasures the tabs in the same command. Measuring needs a left-justified, single-line status bar whose window list fits. Otherwise the window moves on release only.

**Ignoring stray drags.** A drag counts only when it began with a press on a tab within the last 10 seconds. A drag that starts inside a pane, such as a text selection in vim, never pressed a tab, so crossing or releasing over the bar moves nothing.

## Development

| Command | What it does |
|:--------|:-------------|
| `make test` | Runs the bats suite |
| `make lint` | Runs shellcheck on every shell file |
| `make coverage` | Measures line coverage with kcov and fails below 95 percent, on Linux |

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
| [`tmux-extract-revamped`](https://github.com/tmux-revamped/tmux-extract-revamped) | Pick a URL, path, hash or any other token off the screen with fzf and type it at the cursor, in pure shell |
| [`tmux-fzf-revamped`](https://github.com/tmux-revamped/tmux-fzf-revamped) | Switch to, kill, rename or create tmux sessions, windows and panes from fzf pickers in a popup |
| [`tmux-git-revamped`](https://github.com/tmux-revamped/tmux-git-revamped) | Show the active pane's git branch, changes and provider counts in the tmux status bar without blocking it |
| [`tmux-gpu-revamped`](https://github.com/tmux-revamped/tmux-gpu-revamped) | GPU load, temperature, clock, power and memory in the tmux status bar, from NVIDIA, AMD, Intel and Apple GPUs |
| [`tmux-kube-revamped`](https://github.com/tmux-revamped/tmux-kube-revamped) | Current Kubernetes context and namespace in the tmux status bar, parsed from kubeconfig without kubectl |
| [`tmux-launcher-revamped`](https://github.com/tmux-revamped/tmux-launcher-revamped) | Launch any TUI app in a popup or a window, scoped to the current pane's directory, with one configurable bindi |
| [`tmux-logging-revamped`](https://github.com/tmux-revamped/tmux-logging-revamped) | Capture any pane to a file: live logging, full scrollback, or a one-shot screenshot |
| [`tmux-music-revamped`](https://github.com/tmux-revamped/tmux-music-revamped) | Now playing in your tmux status bar, without ever blocking the status render |
| [`tmux-network-revamped`](https://github.com/tmux-revamped/tmux-network-revamped) | Network throughput in your tmux status bar, without ever blocking the render |
| [`tmux-pain-control-revamped`](https://github.com/tmux-revamped/tmux-pain-control-revamped) | Pane and window management bindings for tmux, version aware, vim friendly, every prefix key can be disabled |
| [`tmux-persist-revamped`](https://github.com/tmux-revamped/tmux-persist-revamped) | Save every tmux session, window and pane, auto-save on a timer, and restore it all after a reboot |
| [`tmux-plugin-template`](https://github.com/tmux-revamped/tmux-plugin-template) | The starting point for a tmux-revamped plugin: shared library, bats harness, CI and family tooling |
| [`tmux-pomodoro-revamped`](https://github.com/tmux-revamped/tmux-pomodoro-revamped) | A Pomodoro timer in the tmux status bar that keeps all of its state in tmux options, with no temp files |
| [`tmux-ram-revamped`](https://github.com/tmux-revamped/tmux-ram-revamped) | RAM, swap and memory pressure in the tmux status bar, sampled in the background so the render never waits |
| [`tmux-reorder-revamped`](https://github.com/tmux-revamped/tmux-reorder-revamped) | **this plugin**, Drag a window tab along the tmux status bar with the mouse to move that window |
| [`tmux-scroll-revamped`](https://github.com/tmux-revamped/tmux-scroll-revamped) | Send the mouse wheel to apps that scroll themselves and into tmux copy-mode everywhere else |
| [`tmux-sensible-revamped`](https://github.com/tmux-revamped/tmux-sensible-revamped) | Sensible tmux defaults, gated by tmux version and terminal, that leave the options you set alone |
| [`tmux-tiling-revamped`](https://github.com/tmux-revamped/tmux-tiling-revamped) | Tiling window management for tmux: eight layouts including BSP dwindle and spiral, with layout undo |
| [`tmux-time-revamped`](https://github.com/tmux-revamped/tmux-time-revamped) | Local and world clocks for the tmux status bar, colored by time of day, with countdowns and a DST warning |
| [`tmux-weather-revamped`](https://github.com/tmux-revamped/tmux-weather-revamped) | Weather for the tmux status bar from wttr.in, fetched in the background so the status line never waits |

### Checking an installation

With every member on disk, one command reports any conflict between them:

```sh
family/bin/doctor --live
```

It reads each member and the running tmux server, and reports duplicate keys,
duplicate status placeholders, options outside the naming grammar, and any
member whose contract version has fallen behind.

<!-- family:end -->
