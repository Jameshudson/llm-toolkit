#!/usr/bin/env bash
# install.sh — install the llm CLI on this machine.
#
# From a clone:
#   ./install.sh [--prefix DIR]
#
# Via curl (no clone needed — downloads the toolkit):
#   curl -fsSL https://raw.githubusercontent.com/Jameshudson/llm-toolkit/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- --prefix /usr/local
#
# Env / flags:
#   PREFIX     install prefix (default ~/.local)      --prefix DIR
#   LLM_REPO   GitHub owner/repo                      --repo owner/repo
#   LLM_REF    branch or tag (default main)           --ref REF
#
# Copies the toolkit to <prefix>/share/llm-toolkit and puts `llm`, `or-key`, and
# `spend` on PATH via wrappers in <prefix>/bin. Remove with ./uninstall.sh.
set -euo pipefail

REPO="${LLM_REPO:-Jameshudson/llm-toolkit}"
REF="${LLM_REF:-main}"

PREFIX="${PREFIX:-$HOME/.local}"
while [ $# -gt 0 ]; do
  case "$1" in
    --prefix)   PREFIX="${2:?--prefix needs a value}"; shift 2 ;;
    --prefix=*) PREFIX="${1#*=}"; shift ;;
    --repo)     REPO="${2:?--repo needs a value}"; shift 2 ;;
    --ref)      REF="${2:?--ref needs a value}"; shift 2 ;;
    -h|--help)  echo "usage: install.sh [--prefix DIR] [--repo owner/repo] [--ref REF]"; exit 0 ;;
    *)          PREFIX="$1"; shift ;;
  esac
done
DEST="$PREFIX/share/llm-toolkit"
BIN="$PREFIX/bin"

say() { printf '%s\n' "$*"; }

say "llm-toolkit installer"
say "  to: $DEST"
say

# --- prerequisites ------------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  say "  ! docker not found — install OrbStack (brew install --cask orbstack) or Docker Desktop"
elif ! docker info >/dev/null 2>&1; then
  say "  ! docker daemon not reachable — start your container runtime before running llm"
fi
command -v python3 >/dev/null 2>&1 || say "  ! python3 not found — the 'spend' command needs it"

# --- source the toolkit: a local clone, else download it ----------------------
tmp=""
cleanup() { if [ -n "$tmp" ]; then rm -rf "$tmp"; fi; }
trap cleanup EXIT

SRC=""
self="${BASH_SOURCE[0]:-}"
if [ -n "$self" ] && [ -f "$self" ]; then
  candidate="$(cd "$(dirname "$self")" && pwd)"
  [ -f "$candidate/bin/llm" ] && SRC="$candidate"
fi

if [ -z "$SRC" ]; then
  command -v curl >/dev/null 2>&1 || { say "  ! curl not found — needed to download the toolkit"; exit 1; }
  command -v tar  >/dev/null 2>&1 || { say "  ! tar not found — needed to unpack the toolkit"; exit 1; }
  tmp="$(mktemp -d)"
  say "  downloading ${REPO}@${REF} ..."
  if ! curl -fsSL "https://codeload.github.com/${REPO}/tar.gz/${REF}" | tar -xz -C "$tmp"; then
    say "  ! failed to download ${REPO}@${REF} (set --repo/--ref?)"
    exit 1
  fi
  for d in "$tmp"/*/; do [ -d "$d" ] && { SRC="${d%/}"; break; }; done
  [ -n "$SRC" ] && [ -f "$SRC/bin/llm" ] || { say "  ! download did not contain the toolkit"; exit 1; }
fi

# --- copy the toolkit ---------------------------------------------------------
mkdir -p "$DEST" "$BIN"
for item in bin images template include.mk; do
  rm -rf "$DEST/$item"
  cp -R "$SRC/$item" "$DEST/$item"
done
say "  installed toolkit to $DEST"

# --- wrappers -----------------------------------------------------------------
for c in llm or-key spend; do
  printf '#!/usr/bin/env bash\nexec "%s/bin/%s" "$@"\n' "$DEST" "$c" > "$BIN/$c"
  chmod +x "$BIN/$c"
done
say "  installed: $BIN/{llm,or-key,spend}"

# --- PATH ---------------------------------------------------------------------
case ":$PATH:" in
  *":$BIN:"*) say "  PATH: ok ($BIN is already on PATH)";;
  *) say "  PATH: add this to your shell profile (~/.zshrc):"
     say "          export PATH=\"$BIN:\$PATH\"";;
esac

say
say "next:"
say "  cd <your-project> && llm init && llm opencode   # llm prompts for your key once"
