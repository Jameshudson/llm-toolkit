#!/usr/bin/env bash
# uninstall.sh — remove the llm CLI installed by install.sh.
#
#   ./uninstall.sh                 # remove CLI (same PREFIX as install)
#   ./uninstall.sh --prefix /usr/local
#   ./uninstall.sh --images        # also remove the llm-toolkit Docker images
#
# Via curl (no clone needed):
#   curl -fsSL https://raw.githubusercontent.com/Jameshudson/llm-toolkit/main/uninstall.sh | bash
#
# Project .llm-toolkit/ directories are never touched.
set -euo pipefail

# PREFIX from the environment, or --prefix DIR, or a bare DIR argument.
PREFIX="${PREFIX:-$HOME/.local}"
REMOVE_IMAGES=0
while [ $# -gt 0 ]; do
  case "$1" in
    --prefix)   PREFIX="${2:?--prefix needs a value}"; shift 2 ;;
    --prefix=*) PREFIX="${1#*=}"; shift ;;
    --images)   REMOVE_IMAGES=1; shift ;;
    -h|--help)  echo "usage: uninstall.sh [--prefix DIR] [--images]"; exit 0 ;;
    *)          PREFIX="$1"; shift ;;
  esac
done
DEST="$PREFIX/share/llm-toolkit"
BIN="$PREFIX/bin"

say() { printf '%s\n' "$*"; }

say "llm-toolkit uninstaller"
say

for c in llm or-key spend; do
  if [ -e "$BIN/$c" ]; then rm -f "$BIN/$c"; say "  removed $BIN/$c"; fi
done
if [ -d "$DEST" ]; then rm -rf "$DEST"; say "  removed $DEST"; fi

if [ "$REMOVE_IMAGES" = 1 ]; then
  images="$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -E '(^|/)llm-toolkit:' || true)"
  if [ -n "$images" ]; then
    while IFS= read -r img; do
      if docker rmi "$img" >/dev/null 2>&1; then say "  removed image $img"; else say "  skipped image $img (in use?)"; fi
    done <<< "$images"
  else
    say "  no llm-toolkit images found"
  fi
fi

say
say "kept:"
say "  project .llm-toolkit/ directories — remove them yourself if you want"
[ "$REMOVE_IMAGES" = 1 ] || say "  Docker images — re-run with --images to remove them"
