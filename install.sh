#!/usr/bin/env bash
# install.sh — install the llm CLI on this machine.
#
# Copies the toolkit to <prefix>/share/llm-toolkit and puts `llm`, `or-key`, and
# `spend` on PATH via small wrappers in <prefix>/bin. Nothing else is touched;
# Docker images are built or pulled on first use.
#
#   ./install.sh                    # install to ~/.local
#   ./install.sh --prefix /usr/local
#   PREFIX=/usr/local ./install.sh
#
# Remove it with ./uninstall.sh (use the same PREFIX).
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# PREFIX from the environment, or --prefix DIR, or a bare DIR argument.
PREFIX="${PREFIX:-$HOME/.local}"
while [ $# -gt 0 ]; do
  case "$1" in
    --prefix)   PREFIX="${2:?--prefix needs a value}"; shift 2 ;;
    --prefix=*) PREFIX="${1#*=}"; shift ;;
    -h|--help)  sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)          PREFIX="$1"; shift ;;
  esac
done
DEST="$PREFIX/share/llm-toolkit"
BIN="$PREFIX/bin"

say() { printf '%s\n' "$*"; }

say "llm-toolkit installer"
say "  from: $SRC"
say "  to:   $DEST"
say

# --- prerequisites ------------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  say "  ! docker not found — install OrbStack (brew install --cask orbstack) or Docker Desktop"
fi
if command -v docker >/dev/null 2>&1 && ! docker info >/dev/null 2>&1; then
  say "  ! docker daemon not reachable — start your container runtime before running llm"
fi
if ! command -v python3 >/dev/null 2>&1; then
  say "  ! python3 not found — the 'spend' command needs it"
fi

# --- copy the toolkit ---------------------------------------------------------
mkdir -p "$DEST" "$BIN"
for item in bin images template include.mk; do
  rm -rf "$DEST/$item"
  cp -R "$SRC/$item" "$DEST/$item"
done
say "  copied: bin/ images/ template/ include.mk"

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
say "  cd <your-project> && llm init && \$EDITOR .llm-toolkit/.env"
say "  llm opencode    # pulls the image if LLM_REGISTRY is set, else builds it"
