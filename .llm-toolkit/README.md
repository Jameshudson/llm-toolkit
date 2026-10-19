# .llm-toolkit

Per-project settings and state for the `llm` CLI.

Commit this directory, except the runtime state:

    .llm-toolkit/data/

## What's here

| Path | Purpose |
|---|---|
| `config/` | opencode/pi config for this project. Edit and commit; `llm config` re-seeds it from the defaults (overwriting). |
| `image/` | Container config: derived `Dockerfile`, `mounts`, `on-start.sh`. |
| `data/` | Harness runtime state (sessions, auth, caches) — gitignored. |

Keys live in the repo's root `.env` (gitignored), managed by `llm init`. They're
user-level: if one is missing, `llm` prompts for it once and saves it to
`~/.llm-toolkit/settings.json`, reused across repos. Set a key in `.env` only to
override it for this repo.

## Optional files

Create any of these under `.llm-toolkit/image/` to customize how the container
runs.

### mounts

Extra docker mounts, one `host:container[:opts]` per line. `#` comments, blank
lines, a leading `~` (expands to the host `$HOME`), and `$VAR` / `${VAR}`
(expands from the environment) are supported on either side; relative host paths
resolve from the repo root.

    # .llm-toolkit/image/mounts
    ~/.aws:/root/.aws:ro
    ~/.config/gh:/root/.config/gh:ro
    ../shared-schemas:/workspace/schemas

Expanding `~` or a variable on *both* sides mounts a host directory at the same
absolute path inside the container, so host filesystem paths resolve unchanged.
Handy for dragging files (e.g. screenshots) into the harness — macOS drops
dragged screenshots in `$TMPDIR`:

    # .llm-toolkit/image/mounts
    ~/Desktop:~/Desktop:ro
    $TMPDIR:$TMPDIR:ro

### Dockerfile

A derived image for extra tools, built per harness as
`llm-toolkit:repo-<repo>-<harness>` and used automatically. The build context is
`image/`, so you can `COPY` files from it. `HARNESS` selects the base (`base` has
no Node).

    # .llm-toolkit/image/Dockerfile
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

    # .llm-toolkit/image/on-start.sh
    #!/usr/bin/env bash
    set -e
    command -v psql >/dev/null || { apt-get update && apt-get install -y --no-install-recommends postgresql-client; }

Run `llm --help` for the CLI; see the llm-toolkit repo for the toolkit itself.
