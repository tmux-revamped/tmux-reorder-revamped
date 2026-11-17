# tmux-reorder-revamped

Guidance for anyone, human or agent, changing tmux-reorder-revamped. What it is and how to use it lives in [README.md](README.md).

[FAMILY.md](FAMILY.md) holds everything this plugin shares with the rest of the tmux-revamped family, and it is the same in every member. This file holds only what is exclusive to tmux-reorder-revamped, under the same headings as the agent guide of every member. Read both before changing anything; a rule that would serve the other members goes into [`FAMILY.md`](FAMILY.md) instead of here.

## Layout

| Path | Holds |
|:-----|:------|
| [`reorder-revamped.tmux`](reorder-revamped.tmux) | The entry point TPM runs: it runs `bin/reorder-revamped apply` |
| [`bin/reorder-revamped`](bin/reorder-revamped) | The command: `apply`, `list`, `grab`, `slide`, `drop`, `edge`, `doctor`, `version`, `help` and the menu. `apply` and the four drag commands run without loading the interface modules |
| [`lib/reorder.sh`](lib/reorder.sh) | Reading the settings, the binding plan, the tab measurement and the moves |
| [`lib/state.sh`](lib/state.sh) | Every global, including `REORDER_REVAMPED_SETTINGS`, the table of setting names and defaults the rest reads, and the names of the drag state options |
| [`lib/core.sh`](lib/core.sh) | The version |
| [`lib/`](lib) | Every other file is the shared library, identical in every member |
| [`test/reorder.bats`](test/reorder.bats), [`test/reorder-plan.bats`](test/reorder-plan.bats), [`test/commands.bats`](test/commands.bats), [`test/entrypoint.bats`](test/entrypoint.bats), [`test/mouse.bats`](test/mouse.bats) | This member's suites: the library, the commands, the bindings and moves on a private tmux server, and real mouse drags sent from a second tmux attached to it |
| [`screens/`](screens) | The tapes and the recording's tmux config, with the status line on top so the tapes can drag tabs at fixed columns |

## Names

- Settings are the tmux options `@reorder_revamped_<setting>` listed in `REORDER_REVAMPED_SETTINGS`, the long options with dashes, such as `--edges`, and the environment variables `REORDER_REVAMPED_<SETTING>`.
- The plugin writes its drag state to `@reorder_revamped_source`, `_seen`, `_hit`, `_probe`, `_hover`, `_pressed`, `_pressed_at` and `_press_original`; they are state, never settings.
- It has no status placeholders.
- The version constant is `REORDER_REVAMPED_VERSION`.

## Behaviour

- `apply` reads every setting, the status justification and the saved press command with one `tmux display-message` call, reads `list-keys` once, builds the plan, and sends every binding to tmux in one call separated by `;`.
- A mode or timeout `apply` got from the command line or the environment rides on the drop and edge bindings as `--mode` and `--timeout`, since neither exists when tmux runs a binding; one from the tmux option is left off, so `drop` and `edge` read it when a drag ends and a change needs no reload.
- An empty tmux option means its default.
- The entry point clears every inherited `REVAMPED_` variable except the test switches, and every `REORDER_REVAMPED_*_LOADED` guard; every other global is assigned outright in the state file.
- It binds the status line mouse keys in the root table, declared in the family key allocation, and no prefix key.

## Domain rules

- The first motion of a drag stores the pressed tab with `set-option -F`, which starts no process; `slide` runs only when the pointer enters a different tab.
- On tmux 3.2 to 3.7 tmux reports the tab under the pointer; on 3.8 and later it keeps reporting the tab where the drag started, so `grab` measures every tab with the `#{w:}` width modifier and the drag maps `mouse_x` through the stored format.
- A move is one tmux command of adjacent `swap-window -d` steps by real window index, followed by `select-window`, and a slide that remeasures writes the new format in the same command.
- A drag counts only when it began with a press on a tab within the last 10 seconds, so a selection that starts in a pane moves nothing.
- `MouseDown1Status` is wrapped, never replaced: the command bound before the plugin is saved once in `@reorder_revamped_press_original` and runs after the press is recorded. A release or click binding the person owns is left alone, and turning edges off unbinds only edge bindings that clear `@reorder_revamped_source`.

## Release

- `REORDER_REVAMPED_VERSION` in [`lib/core.sh`](lib/core.sh) holds the version. Nobody edits it by hand.
- After a green `ci` run on `main`, [`release.yml`](.github/workflows/release.yml) runs semantic-release: a `feat` or `fix` since the last tag publishes a release, [`set-version.sh`](.github/scripts/set-version.sh) stamps the constant, and the notes go into [`CHANGELOG.md`](CHANGELOG.md).

## Gaps against FAMILY.md

As of 2026-11-17, none.
