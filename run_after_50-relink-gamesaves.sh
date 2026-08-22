#!/bin/bash
# Recreate the ~/.config/gamesaves symlink topology.
#
# Several emulators keep their saves in ~/.config/gamesaves and reach them
# through a symlink at their own native path. Emu-Backup mirrors gamesaves,
# but a restore only puts the files back; nothing recreates the links. On a
# bare-metal rebuild the emulators would silently start with empty saves
# beside a perfectly good backup. This runs after every chezmoi apply and
# puts the links back.
#
# It is deliberately refuse-first. It will create a link only when doing so
# cannot destroy anything: the path is missing, or it is an empty directory.
# Anything else (real files present, a link pointing somewhere unexpected)
# is reported and left completely alone. It never deletes a file.
set -uo pipefail

GS="$HOME/.config/gamesaves"

# link<TAB>target
LINKS=(
  "$HOME/.local/share/scummvm/saves	$GS/scummvm/saves"
  "$HOME/.local/share/duckstation/memcards	$GS/duckstation/memcards"
  "$HOME/.local/share/duckstation/savestates	$GS/duckstation/savestates"
  "$HOME/.config/retroarch/saves	$GS/retroarch/saves"
  "$HOME/.config/retroarch/states	$GS/retroarch/states"
  "$HOME/.local/share/dolphin-emu/GC	$GS/dolphin/GC"
  "$HOME/.local/share/dolphin-emu/StateSaves	$GS/dolphin/StateSaves"
  "$HOME/.local/share/dolphin-emu/Wii	$GS/dolphin/Wii"
  "$HOME/.local/share/Cemu/mlc01/usr/save	$GS/cemu/save"
)

created=0 ok=0 refused=0 skipped=0

warn() { printf 'relink-gamesaves: %s\n' "$*" >&2; }

for entry in "${LINKS[@]}"; do
  IFS=$'\t' read -r link target <<<"$entry"

  # Never point a link at something that is not there.
  if [[ ! -d "$target" ]]; then
    warn "SKIP  $link -> target missing ($target)"
    skipped=$((skipped + 1))
    continue
  fi

  if [[ -L "$link" ]]; then
    current=$(readlink -f "$link" 2>/dev/null || true)
    if [[ "$current" == "$(readlink -f "$target")" ]]; then
      ok=$((ok + 1))
    else
      warn "REFUSE $link is a symlink to $current, expected $target"
      refused=$((refused + 1))
    fi
    continue
  fi

  if [[ -e "$link" ]]; then
    if [[ ! -d "$link" ]]; then
      warn "REFUSE $link exists and is not a directory"
      refused=$((refused + 1))
      continue
    fi
    # rmdir only succeeds on an empty directory, so a populated save dir
    # can never be removed here even if the test below were wrong.
    if ! rmdir "$link" 2>/dev/null; then
      warn "REFUSE $link is a real directory with $(find "$link" -type f 2>/dev/null | wc -l) file(s); leaving it alone"
      refused=$((refused + 1))
      continue
    fi
  fi

  mkdir -p "$(dirname "$link")"
  if ln -s "$target" "$link" 2>/dev/null; then
    warn "LINK   $link -> $target"
    created=$((created + 1))
  else
    warn "REFUSE could not create $link"
    refused=$((refused + 1))
  fi
done

if (( created > 0 || refused > 0 || skipped > 0 )); then
  warn "summary: $ok ok, $created created, $refused refused, $skipped skipped"
fi
exit 0
