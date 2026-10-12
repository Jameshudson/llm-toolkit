# .llm-toolkit

Per-project settings and state for the `llm` CLI.

Commit this directory, except the secrets and runtime state:

    .llm-toolkit/.env
    .llm-toolkit/data/
    .llm-toolkit/spend/

## What's here

| Path | Purpose |
|---|---|
| `config/` | opencode/pi config for this project. Edit and commit; `llm config` re-seeds it from the defaults (overwriting). |
| `.env` | Per-repo overrides — gitignored. Keys are usually global (see below). |
| `data/` | Harness runtime state (sessions, auth, caches) — gitignored. |
| `spend/sessions.jsonl` | One JSON record per session — gitignored, created on first run. |

Keys are user-level: if one is missing, `llm` prompts for it once and saves it to
`~/.llm-toolkit/settings.json`, reused across repos. Set a key in `.env` only to
override it for this repo.

## Optional files

Create any of these in `.llm-toolkit/` to customize how the container runs.

### mounts

Extra docker mounts, one `host:container[:opts]` per line. `#` comments, blank
lines, and a leading `~` (expands to `$HOME`) are supported; relative host paths
resolve from the repo root.

    # .llm-toolkit/mounts
    ~/.aws:/root/.aws:ro
    ~/.config/gh:/root/.config/gh:ro
    ../shared-schemas:/workspace/schemas

### Dockerfile

A derived image for extra tools, built per harness as
`llm-toolkit:repo-<repo>-<harness>` and used automatically. `HARNESS` selects the
base (`base` has no Node).

    # .llm-toolkit/Dockerfile
    ARG LLM_REGISTRY=
    ARG HARNESS=base
    FROM ${LLM_REGISTRY}llm-toolkit:${HARNESS}
    ARG HARNESS
    RUN apt-get update \
     && apt-get install -y --no-install-recommends postgresql-client \
     && rm -rf /var/lib/apt/lists/*

### on-start.sh

Runs inside the container (as root, in `/workspace`) before the harness starts.
Keep it idempotent — it runs every session.

    # .llm-toolkit/on-start.sh
    #!/usr/bin/env bash
    set -e
    command -v psql >/dev/null || { apt-get update && apt-get install -y --no-install-recommends postgresql-client; }

Run `llm --help` for the CLI; see the llm-toolkit repo for the toolkit itself.
