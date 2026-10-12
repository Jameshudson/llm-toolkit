#!/usr/bin/env bash
# OpenCode setup hook — runs in the opencode image before the harness starts.
#
# Seeds the read-only config into the writable config dir: /opt/opencode-config
# is mounted from the repo/template config, but opencode writes files into
# ~/.config/opencode (e.g. a .gitignore), so that dir must be writable.
set -e

if [ -d /opt/opencode-config ]; then
  mkdir -p /root/.config/opencode
  cp -R /opt/opencode-config/. /root/.config/opencode/ 2>/dev/null || true
fi
