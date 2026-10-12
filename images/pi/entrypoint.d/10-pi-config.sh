#!/usr/bin/env bash
# Pi setup hook — runs in the pi image before the harness starts.
#
# Seeds the read-only pi config into the writable agent dir: /opt/pi-config is
# mounted from the repo's config/pi/agent; /root/.pi/agent holds sessions and
# cached catalog data. `cp -n` keeps first-run defaults without clobbering state.
set -e

if [ -d /opt/pi-config ]; then
  mkdir -p /root/.pi/agent
  for f in /opt/pi-config/*; do
    [ -e "$f" ] || continue
    cp -n "$f" /root/.pi/agent/ 2>/dev/null || true
  done
fi
