# tmux-reorder-revamped

Guidance for anyone, human or agent, changing tmux-reorder-revamped. What it is and how to use it lives in [README.md](README.md).

[FAMILY.md](FAMILY.md) holds everything this plugin shares with the rest of the tmux-revamped family, and it is the same in every member. This file holds only what is exclusive to tmux-reorder-revamped, under the same headings as the agent guide of every member. Read both before changing anything; a rule that would serve the other members goes into [`FAMILY.md`](FAMILY.md) instead of here.

## Layout

| Path | Holds |
|:-----|:------|
| [`reorder-revamped.tmux`](reorder-revamped.tmux) | The entry point TPM runs |
| [`src/reorder.sh`](src/reorder.sh) | The script the entry point and the keys call |
| [`src/lib/reorder/`](src/lib/reorder) | This member's modules |
| [`src/lib/utils/constants.sh`](src/lib/utils/constants.sh) | This member's constants, including its version |
| [`src/lib/utils/`](src/lib/utils), [`src/lib/tmux/`](src/lib/tmux) | The shared library. Every file there except `constants.sh` is owned by the family |
| [`test/`](test) | The bats suite. `helpers.bash` and `tmux_helpers.bash` are owned; this member's own mocks go in the `_local` files |
| [`family/`](family) | The family tooling, owned |

## Names

- Settings are tmux options named `@reorder_revamped_<setting>`.
- It has no status placeholders.
- Public functions carry `reorder_`; private ones start with `_`.
- The version constant is `REORDER_REVAMPED_VERSION`.
- Its command-line tool, once it exists, is `reorder-revamped`.

## Behaviour

- Moves a window by dragging its tab along the status line with the mouse.
- It binds the status line mouse keys in the root table, declared in the family key allocation.
- The first motion of a drag stores the pressed tab in a server option with `set-option -F`, which starts no process. Only when the pointer enters a different tab does `src/reorder.sh slide` run.

## Domain rules

- On tmux 3.2 to 3.7 tmux reports the tab under the pointer; on 3.8 and later it keeps reporting the tab where the drag started, so `grab` measures every tab with the `#{w:}` width modifier and tracks `mouse_x`.
- A slide is one tmux command of adjacent `swap-window -d` steps that also remeasures the tabs.
- A drag counts only when it began with a press on a tab within the last 10 seconds, so a selection that starts in a pane moves nothing.

## Release

- `REORDER_REVAMPED_VERSION` in [`src/lib/utils/constants.sh`](src/lib/utils/constants.sh) holds the version. It must equal the newest versioned heading in [`CHANGELOG.md`](CHANGELOG.md) and the README's version badge, which the `version` job in `tests.yml` checks.
- A push to `main` whose version has no tag yet makes the `release` job in `tests.yml` tag `vX.Y.Z` and publish a GitHub release with that changelog section.
- Unreleased changes sit under `## [Unreleased]` in [`CHANGELOG.md`](CHANGELOG.md) until a release is cut.

## Gaps against FAMILY.md

As of 2026-11-15:

- Every script is bash, under `#!/usr/bin/env bash`, not POSIX `sh`, so it is untested under `dash`, `zsh` and BusyBox `sh`.
- The code lives in [`src/`](src) and [`src/lib/`](src/lib); there is no `bin/reorder-revamped`, `lib/state.sh` or `lib/core.sh`.
- No `reorder-revamped` command with `help`, `version` and `doctor` in the family's form, no man page, no completions and no `manifest.json`.
- No gum interface: no `lib/ui.sh`, `lib/table.awk`, themes or `test/bin/gum`.
- No `screens/` and no recordings in the README.
- The README sections are not the family's order of Quick start, Usage, topic sections, Portability, Development and License.
- Coverage is kcov with a 95 percent floor on Linux, not bashcov at 100 percent merged from macOS and Linux.
- CI tests GNU, BSD and uutils tools in `tests.yml`, but not the six toolsets through `.github/scripts/toolset.sh`, and no shell matrix under `sh`, `dash`, `bash` and `zsh`.
- No golden transcripts, `call.sh`, `run-matrix.sh` or `linux-container.sh`.
- The version is written by hand and released by `tests.yml`; there is no semantic-release, `package.json`, `release.yml` with `recover`, `bot-merge.yml` or Renovate.
- CI is `tests.yml`, `family.yml` and `security.yml`, not `ci.yml`, and no job starts with `step-security/harden-runner`.
- The pull request template, `labeler.yml`, `pr.yml` and `stale.yml` are still present.
- No `.editorconfig`, `.yamllint.yml`, `scripts/check-names.sh` or shfmt; the Makefile has `help`, `test`, `test-unit`, `coverage`, `lint` and `clean`, not the family's targets.
