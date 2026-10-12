# llm-toolkit — build/publish the harness images and run them with per-session
# spend tracking.
#
#   make build                  build base + node + harness images (and repo image)
#   make publish                build and push all images to $(LLM_REGISTRY)
#   make install                install the llm/or-key/spend CLI into $(PREFIX)/bin
#   make uninstall              remove the installed CLI
#   make init                   create .env + state dir in this repo
#   make config                 copy toolkit config into the repo for customization
#   make opencode               interactive opencode
#   make pi                     interactive pi
#   make shell                  a shell inside the base image
#   make run HARNESS=pi ARGS="summarise this repo"
#   make keys / key-create / key-delete
#   make spend / spend-csv
#
# Set LLM_REGISTRY=ghcr.io/<you>/ to build and publish registry-tagged images;
# leave empty for local tags. Repos consume the images via the installed CLI and
# a per-repo .llm-toolkit/ dir — see the README.

TOOLKIT_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# The repo the CLI is being run against (the toolkit itself when standalone).
REPO_ROOT := $(shell git -C $(TOOLKIT_DIR) rev-parse --show-superproject-working-tree 2>/dev/null)
ifeq ($(REPO_ROOT),)
REPO_ROOT := $(shell git -C $(TOOLKIT_DIR) rev-parse --show-toplevel 2>/dev/null)
endif
ifeq ($(REPO_ROOT),)
REPO_ROOT := $(TOOLKIT_DIR)
endif

# State (.env, data/, spend/) lives in the repo; standalone, in the toolkit.
ifeq ($(REPO_ROOT),$(TOOLKIT_DIR))
STATE_DIR ?= $(REPO_ROOT)
else
STATE_DIR ?= $(REPO_ROOT)/.llm-toolkit
endif

# Images. LLM_REGISTRY is the prefix before "llm-toolkit" (trailing slash), e.g.
# "ghcr.io/you/". Empty means local tags.
LLM_REGISTRY   ?=
BASE_IMAGE     := $(LLM_REGISTRY)llm-toolkit:base
NODE_IMAGE     := $(LLM_REGISTRY)llm-toolkit:node
OPENCODE_IMAGE := $(LLM_REGISTRY)llm-toolkit:opencode
PI_IMAGE       := $(LLM_REGISTRY)llm-toolkit:pi
REPO_SLUG      := $(shell basename $(REPO_ROOT) | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')

# Install location for `make install`.
PREFIX ?= $(HOME)/.local
DEST   := $(PREFIX)/share/llm-toolkit

WORKDIR ?= $(REPO_ROOT)
TERM    ?= xterm-256color
HARNESS ?= opencode
ARGS    ?=
LOADENV := set -a; for f in "$(TOOLKIT_DIR)/.env" "$(STATE_DIR)/.env"; do [ -f "$$f" ] && . "$$f"; done; set +a;

export WORKDIR TERM LLM_REGISTRY
export LLM_STATE_DIR := $(STATE_DIR)

.PHONY: help build build-base build-node build-opencode build-pi publish check-registry install uninstall init config opencode pi shell run keys key-create key-delete spend spend-csv clean

help:
	@sed -n '4,19p' $(MAKEFILE_LIST) | sed 's/^# \{0,1\}//'

build: build-base build-node build-opencode build-pi
	@if [ -f "$(STATE_DIR)/Dockerfile" ]; then \
		for h in base opencode pi; do \
			echo "building llm-toolkit:repo-$(REPO_SLUG)-$$h ..."; \
			docker build -f "$(STATE_DIR)/Dockerfile" \
				--build-arg "LLM_REGISTRY=$(LLM_REGISTRY)" --build-arg "HARNESS=$$h" \
				-t "llm-toolkit:repo-$(REPO_SLUG)-$$h" "$(STATE_DIR)"; \
		done; \
	else \
		echo "no $(STATE_DIR)/Dockerfile — base images only"; \
	fi

build-base:
	docker build -f $(TOOLKIT_DIR)/container/base/Dockerfile -t $(BASE_IMAGE) $(TOOLKIT_DIR)

build-node: build-base
	docker build -f $(TOOLKIT_DIR)/container/node/Dockerfile \
		--build-arg "BASE_REF=$(BASE_IMAGE)" -t $(NODE_IMAGE) $(TOOLKIT_DIR)

build-opencode: build-node
	docker build -f $(TOOLKIT_DIR)/container/opencode/Dockerfile \
		--build-arg "NODE_REF=$(NODE_IMAGE)" -t $(OPENCODE_IMAGE) $(TOOLKIT_DIR)

build-pi: build-node
	docker build -f $(TOOLKIT_DIR)/container/pi/Dockerfile \
		--build-arg "NODE_REF=$(NODE_IMAGE)" -t $(PI_IMAGE) $(TOOLKIT_DIR)

check-registry:
	@[ -n "$(LLM_REGISTRY)" ] || { echo "set LLM_REGISTRY, e.g. ghcr.io/<you>/" >&2; exit 1; }

publish: check-registry build
	docker push $(BASE_IMAGE)
	docker push $(NODE_IMAGE)
	docker push $(OPENCODE_IMAGE)
	docker push $(PI_IMAGE)

install:
	@mkdir -p "$(DEST)" "$(PREFIX)/bin"
	@cp -R "$(TOOLKIT_DIR)/bin" "$(TOOLKIT_DIR)/container" "$(TOOLKIT_DIR)/config" \
		"$(TOOLKIT_DIR)/include.mk" "$(TOOLKIT_DIR)/.env.example" "$(DEST)/"
	@for c in llm or-key spend; do \
		printf '#!/usr/bin/env bash\nexec "%s/bin/%s" "$$@"\n' "$(DEST)" "$$c" > "$(PREFIX)/bin/$$c"; \
		chmod +x "$(PREFIX)/bin/$$c"; \
	done
	@echo "installed llm, or-key, spend into $(PREFIX)/bin"
	@echo "toolkit data at $(DEST)"
	@case ":$$PATH:" in *":$(PREFIX)/bin:"*) ;; *) echo "note: add $(PREFIX)/bin to PATH";; esac

uninstall:
	@rm -f "$(PREFIX)/bin/llm" "$(PREFIX)/bin/or-key" "$(PREFIX)/bin/spend"
	@rm -rf "$(DEST)"
	@echo "removed $(PREFIX)/bin/{llm,or-key,spend} and $(DEST)"

init:
	@mkdir -p "$(STATE_DIR)/data"
	@if [ ! -f "$(STATE_DIR)/.env" ]; then cp "$(TOOLKIT_DIR)/.env.example" "$(STATE_DIR)/.env"; echo "created $(STATE_DIR)/.env"; else echo "kept existing $(STATE_DIR)/.env"; fi
	@if [ "$(STATE_DIR)" = "$(TOOLKIT_DIR)" ]; then echo "add to .gitignore: .env, /data/, /spend/"; else echo "add to .gitignore: $(patsubst $(REPO_ROOT)/%,%,$(STATE_DIR))/"; fi

config:
	@mkdir -p "$(STATE_DIR)/config"
	@cp -R "$(TOOLKIT_DIR)/config/." "$(STATE_DIR)/config/"
	@echo "copied toolkit config to $(STATE_DIR)/config (edit to override per repo)"

opencode:
	@"$(TOOLKIT_DIR)/bin/llm" opencode $(ARGS)

pi:
	@"$(TOOLKIT_DIR)/bin/llm" pi $(ARGS)

shell:
	@"$(TOOLKIT_DIR)/bin/llm" shell

run:
	@"$(TOOLKIT_DIR)/bin/llm" run --harness $(HARNESS) $(ARGS)

keys:
	@$(LOADENV) "$(TOOLKIT_DIR)/bin/or-key" list

key-create:
	@$(LOADENV) "$(TOOLKIT_DIR)/bin/or-key" create --name "$(NAME)" $(if $(LIMIT),--limit $(LIMIT),)

key-delete:
	@$(LOADENV) "$(TOOLKIT_DIR)/bin/or-key" delete "$(HASH)"

spend:
	@LLM_STATE_DIR="$(STATE_DIR)" python3 "$(TOOLKIT_DIR)/bin/spend" summary

spend-csv:
	@LLM_STATE_DIR="$(STATE_DIR)" python3 "$(TOOLKIT_DIR)/bin/spend" csv

clean:
	rm -rf "$(STATE_DIR)/data" "$(STATE_DIR)/spend"
