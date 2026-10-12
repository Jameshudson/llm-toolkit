# llm-toolkit

Run coding harnesses (`opencode`, `pi`) inside a container — nothing installed
on the host — with per-session spend tracking.

`llm-toolkit` builds and (optionally) publishes a small set of Docker images and
ships a `llm` CLI. Project repos don't vendor any of it: they pull the images and
use the CLI, keeping only a gitignored `.llm-toolkit/` directory for per-repo
configuration and state.

## What it does

- **Modular images.** `llm-toolkit:base` has the OS toolchain (git, ripgrep,
  jq, ssh, …) but no Node and no harness. `llm-toolkit:node` adds Node 24, and
  `llm-toolkit:opencode` / `llm-toolkit:pi` add one harness each.
- **Provider keys via env.** OpenRouter and DeepSeek keys are injected as
  environment variables and never written into the repo.
- **Per-session spend.** With an OpenRouter *management* key, each session mints
  its own scoped API key; its `usage` is read back at exit and appended to
  `.llm-toolkit/spend/sessions.jsonl`.
- **Per-repo customization.** Each repo can add mounts, extra tools, config
  overrides, and an on-start hook via `.llm-toolkit/`.

## Layout

```
bin/llm         CLI: mint a session key, run the container, record spend
bin/or-key      OpenRouter Management API helper (create/list/get/delete keys)
bin/spend       report on sessions.jsonl (summary / list / csv)
container/      base/, node/, opencode/, pi/ image definitions + shared entrypoint
config/         default opencode/pi config, mounted read-only
include.mk      optional make sugar for project repos
```

## Install (this repo)

```sh
make build        # build base + node + opencode + pi (local tags)
make install      # put llm, or-key, spend on PATH (~/.local/bin)
```

`make install` copies the toolkit to `~/.local/share/llm-toolkit` and installs
wrapper scripts into `~/.local/bin` (override with `PREFIX=/some/prefix`). Make
sure that directory is on `PATH`.

Requires a running container runtime. OrbStack is recommended
(`brew install --cask orbstack`).

### Publish (optional)

This repo's images are published to GHCR as
`ghcr.io/jameshudson/llm-toolkit:{base,node,opencode,pi}` by the
`images` GitHub Actions workflow (`.github/workflows/images.yml`) on push to
`main`, on `v*` tags, or via manual dispatch. It builds multi-arch
(amd64 + arm64), so Apple Silicon pulls a native image.

To publish by hand instead:

```sh
export LLM_REGISTRY=ghcr.io/jameshudson/
make publish      # builds and pushes llm-toolkit:{base,node,opencode,pi}
```

`LLM_REGISTRY` is the prefix before `llm-toolkit` (trailing slash). With it set,
`llm` pulls images and only falls back to a local build if the pull fails; with
it empty, images use local tags and are built on demand. GHCR packages are
private by default — run `docker login ghcr.io` (or make the package public in
its settings) before pulling.

## Images

| Image | Contents |
|---|---|
| `llm-toolkit:base` | Debian bookworm-slim + git, ripgrep, jq, curl, ssh, and archive tools. No Node, no harness. |
| `llm-toolkit:node` | base + Node 24. Shared by both harness images. |
| `llm-toolkit:opencode` | node + opencode. |
| `llm-toolkit:pi` | node + pi. |
| `llm-toolkit:repo-<name>-<harness>` | optional per-repo derived image (see below). |

`llm <harness>` uses `<registry>llm-toolkit:<harness>`; `llm shell` uses the base
(or the repo's derived base). Override with `LLM_IMAGE=<tag>`. Build individual
layers with `make build-base`, `make build-node`, `make build-opencode`,
`make build-pi`.

## Keys

| Variable | Purpose |
|---|---|
| `OPENROUTER_MANAGEMENT_KEY` | Admin key from <https://openrouter.ai/settings/management-keys>. Enables per-session key minting. Cannot make inference calls. |
| `OPENROUTER_API_KEY` | Fallback inference key when no management key is set. |
| `DEEPSEEK_API_KEY` | Injected as-is. DeepSeek has no key-management API, so keys are created in their web UI. |
| `SESSION_LIMIT` | Optional USD credit limit applied to each per-session OpenRouter key. |
| `LLM_SESSION_KEYS` | `0` disables per-session key minting. |

## Use in a project repo

From anywhere inside a git repo:

```sh
llm init          # creates .llm-toolkit/, seeds .env, prints gitignore lines
$EDITOR .llm-toolkit/.env
llm opencode      # or: llm pi
```

That's the whole integration — no submodule, no vendored files. `llm` finds the
enclosing repo, keeps state in `.llm-toolkit/`, and runs against the repo root.

Add `.llm-toolkit/` to `.gitignore`.

Optional make sugar — add one line to the repo's Makefile:

```make
-include $(HOME)/.local/share/llm-toolkit/include.mk
```

then `make llm-opencode`, `make llm-pi`, `make llm-shell`, `make llm-run
HARNESS=pi ARGS="..."`, `make llm-spend`.

### Where state lives

```
.llm-toolkit/
├── .env            keys and per-repo defaults (gitignored)
├── mounts          extra docker mounts (optional)
├── Dockerfile      derived image for extra tools (optional)
├── on-start.sh     hook run before the harness (optional)
├── config/         opencode/pi config overrides (optional)
├── data/           sessions, auth, caches (gitignored)
└── spend/          sessions.jsonl (gitignored)
```

## Per-repo customization

Everything is optional; the toolkit works with none of it.

### Extra mount paths

Create `.llm-toolkit/mounts`, one `host:container[:opts]` per line. `#`
comments, blank lines, and a leading `~` (expands to `$HOME`) are supported.
Relative host paths resolve from the repo root.

```
# .llm-toolkit/mounts
~/.aws:/root/.aws:ro
~/.config/gh:/root/.config/gh:ro
../shared-schemas:/workspace/schemas
```

To change what is mounted at `/workspace`, set `WORKDIR` in `.env` (or
`llm opencode` with `WORKDIR=...`).

### Extra tools

For tools that should be baked in, add `.llm-toolkit/Dockerfile`. It selects its
base with `ARG HARNESS` (so one file serves every harness):

```dockerfile
ARG LLM_REGISTRY=
ARG HARNESS=base
FROM ${LLM_REGISTRY}llm-toolkit:${HARNESS}
ARG HARNESS
RUN apt-get update \
 && apt-get install -y --no-install-recommends postgresql-client \
 && rm -rf /var/lib/apt/lists/*
```

`llm` builds it as `llm-toolkit:repo-<repo-name>-<harness>` on first use, and the
matching run uses it automatically. Deriving from `base` gives you no Node — use
`HARNESS=opencode` (or `pi`) if the tools need it.

For lighter, on-demand setup, add `.llm-toolkit/on-start.sh` — it runs inside the
container (as root, in `/workspace`) before the harness starts.

### Config overrides

Copy the toolkit's `config/` into `.llm-toolkit/config/` and edit; the per-repo
copy wins over the toolkit defaults.

## Usage

```sh
llm opencode                    # opencode TUI
llm pi                          # pi
llm shell                       # bash inside the container
llm run --harness pi "summarise this repo"
llm opencode WORKDIR=~/x        # run against another directory
MODEL=openrouter/deepseek/deepseek-v4-flash llm pi
```

## Spend tracking

Each session writes one JSONL record to `.llm-toolkit/spend/sessions.jsonl`:

```json
{"session_id":"20261012T134501Z-1234-5678","harness":"opencode",
 "model":"openrouter/deepseek/deepseek-v4-flash","started_at":"...",
 "ended_at":"...","duration_s":412,"exit_code":0,"cwd":"/path",
 "openrouter_key_hash":"...","openrouter_key_label":"llm-toolkit/opencode/...",
 "cost_usd":0.0341,"source":"openrouter-key"}
```

```sh
spend                 # totals, by harness, by model, by day
spend list -n 50
spend csv             # -> .llm-toolkit/spend/sessions.csv
```

Spend comes from the per-session OpenRouter key's `usage`, which is
harness-agnostic. It requires routing inference through OpenRouter (the default
`openrouter/deepseek/*` models do).

**Caveats**

- Direct DeepSeek calls are **not** attributed per session — DeepSeek exposes no
  per-key usage API. `source` is `none` and `cost_usd` is `null`.
- Without `OPENROUTER_MANAGEMENT_KEY`, sessions fall back to `OPENROUTER_API_KEY`
  and are recorded unpriced.
- Key `usage` is read at session exit; a request still in flight may not be
  reflected.
- `llm shell` sessions are not recorded.

## Managing keys

```sh
or-key create --name my-key [--limit 10] [--reset daily] [--raw]
or-key list
or-key get <hash>
or-key delete <hash>
```

`llm` creates keys named `llm-toolkit/<harness>/<session-id>` and leaves them in
place so usage stays queryable. Clean up old ones with `or-key list` and
`or-key delete`.

## Notes

- The base entrypoint is harness-agnostic. Harness-specific setup ships in the
  harness image as a hook under `/etc/llm-toolkit/entrypoint.d/` (pi seeds its
  config that way); a repo can add image hooks too, or use `on-start.sh`.
- The host's `~/.ssh` and git config are mounted for git operations; the SSH
  agent socket is forwarded when available.
- Toolkit `config/` is mounted read-only; per-repo overrides go in
  `.llm-toolkit/config/`.
