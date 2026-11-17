# shellcheck shell=bash
# shellcheck disable=SC2207

_reorder_revamped() {
  local cur prev
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD - 1]}"

  case "${prev}" in
  --theme)
    COMPREPLY=($(compgen -W "kodougu catppuccin-mocha catppuccin-latte dracula nord gruvbox tokyo-night mono" -- "${cur}"))
    return
    ;;
  --mode)
    COMPREPLY=($(compgen -W "insert swap" -- "${cur}"))
    return
    ;;
  --live)
    COMPREPLY=($(compgen -W "on off" -- "${cur}"))
    return
    ;;
  --edges)
    COMPREPLY=($(compgen -W "on off" -- "${cur}"))
    return
    ;;
  --timeout)
    return
    ;;
  --swipe)
    COMPREPLY=($(compgen -W "on off" -- "${cur}"))
    return
    ;;
  edge)
    COMPREPLY=($(compgen -W "first last trailing" -- "${cur}"))
    return
    ;;
  *) ;;
  esac

  COMPREPLY=($(compgen -W "apply list grab slide drop edge swipe doctor version help --json --theme --mode --live --edges --timeout --swipe" -- "${cur}"))
}

complete -F _reorder_revamped reorder-revamped
