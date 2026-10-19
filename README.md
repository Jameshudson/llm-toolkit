# llm-toolkit

Run coding harnesses (`opencode`, `pi`) inside a container — nothing installed
on the host.


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
- **Managed OpenRouter keys.** With an OpenRouter *management* key, `llm` keeps
  one scoped API key per project+harness (cached in `~/.llm-toolkit/keys.json`),
  optionally capped by `SESSION_LIMIT`.
- **Per-repo customization.** Each repo can add mounts, extra tools, config
  overrides, and an on-start hook via `.llm-toolkit/`.

## Layout

```
bin/llm         CLI: manage the OpenRouter key and run the container
bin/or-key      OpenRouter Management API helper (create/list/get/update/delete keys)
images/         base/, node/, opencode/, pi/ image definitions + shared entrypoint
template/       the .llm-toolkit/ template `llm init` copies into a repo
include.mk      optional make sugar for project repos
```

## Install

On a new machine, one line (no clone needed — it downloads the toolkit):

```sh
curl -fsSL https://raw.githubusercontent.com/Jameshudson/llm-toolkit/main/install.sh | bash
```

From a clone:

```sh
./install.sh          # or: make install
```

Either way it copies the toolkit to `~/.local/share/llm-toolkit` and puts `llm`
and `or-key` on PATH via wrappers in `~/.local/bin`. Override the location with
`--prefix DIR` / `PREFIX=…`. Images build on first use, or pull when
`LLM_REGISTRY` is set. Requires a running container runtime (OrbStack
recommended: `brew install --cask orbstack`).

### Uninstall

```sh
curl -fsSL https://raw.githubusercontent.com/Jameshudson/llm-toolkit/main/uninstall.sh | bash
```

From a clone: `./uninstall.sh` (or `make uninstall`); add `--images` to also
remove the llm-toolkit Docker images. Removes the CLI wrappers and the
`~/.local/share/llm-toolkit` copy. Project `.llm-toolkit/` directories are left
untouched.

### Publish (optional)

This repo's images are published to GHCR as
`ghcr.io/jameshudson/llm-toolkit:{base,node,opencode,pi}` by the `images` GitHub
Actions workflow (`.github/workflows/images.yml`). It runs only when the image
definitions change (`images/**`) or on manual dispatch, and builds multi-arch
(amd64 + arm64) so Apple Silicon pulls a native image.

Each layer is tagged three ways:

| Tag | Example | Meaning |
|---|---|---|
| `:<layer>` | `:opencode` | floating latest |
| `:<layer>-<version>` | `:opencode-0.1.0` | release version (`images/VERSION`) |
| `:<layer>-sha-<short>` | `:opencode-sha-abc1234` | immutable, per commit |

Bump `images/VERSION` to cut a release. To pin an image, set
`LLM_IMAGE=ghcr.io/jameshudson/llm-toolkit:opencode-0.1.0` (or the `-sha-…` tag).

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
| `llm-toolkit:base` | Debian bookworm-slim + git, ripgrep, jq, curl, ssh, archive tools, and OSC 52 clipboard shims. No Node, no harness. |
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
| `OPENROUTER_MANAGEMENT_KEY` | Admin key from <https://openrouter.ai/settings/management-keys>. One scoped API key per project+harness. Cannot make inference calls. |
| `OPENROUTER_API_KEY` | Fallback inference key when no management key is set. |
| `DEEPSEEK_API_KEY` | Injected as-is. DeepSeek has no key-management API, so keys are created in their web UI. |
| `SESSION_LIMIT` | USD credit limit applied to the managed key (default `$5`). Empty = no limit; changing it re-syncs the existing key's limit. |
| `LLM_SESSION_KEYS` | `0` disables the managed key and uses `OPENROUTER_API_KEY` directly. |

Keys are resolved in this order (first wins): the environment, the repo's root
`.env`, then a global `~/.llm-toolkit/settings.json`. Put shared secrets (like
`OPENROUTER_MANAGEMENT_KEY`) in the global file so you don't repeat them per
repo; override `LLM_HOME` to relocate it.

Before launching, `llm` reads the provider from the harness config and **refuses
to start** if its key is missing. If you're in a terminal it prompts for the key
(hidden) and saves it to the global file; otherwise it prints what to set.
Bypass with `LLM_SKIP_KEY_CHECK=1` (e.g. when you authenticated another way).
`llm shell` is not checked.

## Use in a project repo

From anywhere inside a git repo:

```sh
llm init          # scaffold .llm-toolkit/, add the .env block + .gitignore entries
$EDITOR .env
llm opencode      # or: llm pi
```

`llm init` copies the toolkit's `template/` into the repo as `.llm-toolkit/`
(`config/`, `image/`, `README.md`), adds a `# --- llm-toolkit ---` block to the
repo's **root `.env`** — creating it, or appending if the block isn't already
there — and adds `.env` and `.llm-toolkit/data/` to the repo's `.gitignore`
(idempotently, only if not already covered).

Commit `.llm-toolkit/` (except its `data/`), and keep the root `.env` out of git.
`llm init` writes those entries to `.gitignore` for you:

```gitignore
.env
.llm-toolkit/data/
```

Keeping `data/` ignored matters: opencode snapshots the workspace with git, so a
data dir left inside the repo (and not ignored) makes each snapshot re-hash the
previous one — runaway CPU and disk. `llm opencode` warns if it ever sees that.

That's the whole integration — no submodule, no vendored files. `llm` finds the
enclosing repo, keeps state in `.llm-toolkit/`, and runs against the repo root.

Optional make sugar — add one line to the repo's Makefile:

```make
-include $(HOME)/.local/share/llm-toolkit/include.mk
```

then `make llm-opencode`, `make llm-pi`, `make llm-shell`, `make llm-run
HARNESS=pi ARGS="..."`.

### What `llm init` creates

```
.llm-toolkit/
├── README.md            what each file is
├── config/              opencode/pi config for this project (commit it)
├── image/               derived Dockerfile, mounts, on-start.sh (commit it)
└── data/                harness sessions, auth, caches (gitignored)

.env                     llm-toolkit keys/settings, at the repo root (gitignored)
```

Everything in `.llm-toolkit/` except `data/` is meant to be committed, and the
root `.env` stays out of git. Optional `image/Dockerfile`, `image/mounts`, and
`image/on-start.sh` files (documented in `.llm-toolkit/README.md`) are created on
demand.

## Per-repo customization

Everything is optional; the toolkit works with none of it.

### Extra mount paths

Create `.llm-toolkit/image/mounts`, one `host:container[:opts]` per line. `#`
comments, blank lines, and a leading `~` (expands to the host `$HOME`) are
supported. Relative host paths resolve from the repo root.

```
# .llm-toolkit/image/mounts
~/.aws:/root/.aws:ro
~/.config/gh:/root/.config/gh:ro
../shared-schemas:/workspace/schemas
```

A `~` on *both* sides mounts a host directory at the same absolute path inside
the container, so host paths resolve unchanged — useful for drag-and-drop:

```
~/Desktop:~/Desktop:ro
~/Downloads:~/Downloads:ro
```

To change what is mounted at `/workspace`, set `WORKDIR` in `.env` (or
`llm opencode` with `WORKDIR=...`).

### Extra tools

For tools that should be baked in, add `.llm-toolkit/image/Dockerfile`. It
selects its base with `ARG HARNESS` (so one file serves every harness), and its
build context is `image/` (so you can `COPY` files from it):

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

For lighter, on-demand setup, add `.llm-toolkit/image/on-start.sh` — it runs
inside the container (as root, in `/workspace`) before the harness starts.

### Config

`.llm-toolkit/config/` holds this project's opencode/pi config, seeded by
`llm init` from the template. Edit and commit it. When it is absent, `llm` falls
back to the template defaults; `llm config` re-seeds it.

## Usage

```sh
llm opencode                    # opencode TUI
llm pi                          # pi
llm shell                       # bash inside the container
llm run --harness pi "summarise this repo"
llm opencode WORKDIR=~/x        # run against another directory
MODEL=openrouter/deepseek/deepseek-v4.1-flash llm pi
```

## Managing keys

```sh
or-key create --name my-key [--limit 10] [--reset daily] [--raw]
or-key list
or-key get <hash>
or-key update <hash> [--limit 10]
or-key delete <hash>
```

`llm` keeps one key per project+harness, named
`llm-toolkit/<host>/<project>/<harness>`, and reuses it (the secret is cached in
`~/.llm-toolkit/keys.json`). Clean up old ones with `or-key list` and
`or-key delete`.

## Dependency updates

Renovate runs self-hosted from `.github/workflows/renovate.yml` (daily, or via
manual dispatch) using the root `renovate.json`. It opens PRs for:

- the Dockerfile base images (`debian:bookworm-slim`, `node:24-bookworm-slim`);
- the GitHub Actions used in `.github/workflows/`;
- the harness versions — annotate an `ARG` with `# renovate:` (see
  `images/opencode/Dockerfile`, `images/pi/Dockerfile`).

Add a `RENOVATE_TOKEN` repo secret: a classic PAT with `repo` scope, plus
`workflow` so it may update files under `.github/workflows/`.

## Notes

- The base entrypoint is harness-agnostic. Harness-specific setup ships in the
  harness image as a hook under `/etc/llm-toolkit/entrypoint.d/` (pi seeds its
  config that way); a repo can add image hooks too, or use `on-start.sh`.
- The host's `~/.ssh` and git config are mounted for git operations; the SSH
  agent socket is forwarded when available.
- There's no display server, so the base image ships `xclip`/`xsel`/`wl-copy`
  shims (`images/base/clip/llm-clip`) that forward copies to the host clipboard
  over OSC 52; the terminal must support it (iTerm2, Ghostty, kitty, WezTerm,
  Alacritty — not Apple Terminal.app). Reads aren't bridged, so paste with the
  terminal's own binding (Cmd+V). opencode's mouse capture is disabled in
  `tui.json` so native selection and Cmd+C keep working.
- A project's `config/` lives in `.llm-toolkit/config/` (committed). The toolkit's
  `template/` is the source it is copied from, and the fallback when a repo
  has none.
