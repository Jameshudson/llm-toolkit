#!/usr/bin/env bash
# Entrypoint for the llm-toolkit images.
#
# Generic setup shared by every image: prepare the workspace and SSH agent, run
# any entrypoint hooks, then exec the requested command (a harness, or bash for
# `llm shell`). Harness-specific setup lives in the harness image as a hook
# under /etc/llm-toolkit/entrypoint.d — base knows nothing about any harness.
set -euo pipefail

cd /workspace

# The repo arrives as a bind mount, so git's ownership check can reject it.
git config --global --add safe.directory /workspace 2>/dev/null || true

# ~/.ssh is mounted read-only at /root/.ssh-host. Copy it to a writable
# /root/.ssh and drop any host-only IdentityAgent line so ssh falls back to the
# forwarded SSH_AUTH_SOCK.
if [ -d /root/.ssh-host ]; then
  mkdir -p /root/.ssh
  cp -a /root/.ssh-host/. /root/.ssh/ 2>/dev/null || true
  chmod 700 /root/.ssh 2>/dev/null || true
  chmod 600 /root/.ssh/id_* 2>/dev/null || true
  if [ -f /root/.ssh/config ]; then
    sed -i '/IdentityAgent/d' /root/.ssh/config
    sed -i '/\.orbstack/d' /root/.ssh/config
  fi
fi

# Hooks, in order: image-provided hooks (harness setup, sorted by name), then
# the per-repo on-start hook. Each is best-effort.
for hook in /etc/llm-toolkit/entrypoint.d/*.sh /opt/llm-toolkit/on-start.sh; do
  [ -f "$hook" ] || continue
  echo "llm-toolkit: running $(basename "$hook")" >&2
  bash "$hook" || echo "llm-toolkit: warning: $(basename "$hook") exited nonzero" >&2
done

exec "$@"
