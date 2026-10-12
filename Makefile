# llm-toolkit — build/publish the harness images and run them.
#
#   make build                  build base + node + harness images (and repo image)
#   make publish                build and push all images to $(LLM_REGISTRY)
#   make install                install the llm/or-key CLI into $(PREFIX)/bin
#   make uninstall              remove the installed CLI
#   make init                   create .env + state dir in this repo
#   make config                 copy toolkit config into the repo for customization
#   make opencode               interactive opencode
#   make pi                     interactive pi
#   make shell                  a shell inside the base image
#   make run HARNESS=pi ARGS="summarise this repo"
#   make keys / key-create / key-delete
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

# State (.env, data/) lives in the repo; standalone, in the toolkit.
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
VERSION        := $(shell tr -d '[:space:]' < $(TOOLKIT_DIR)/images/VERSION 2>/dev/null)

# Install location for `make install` (see install.sh).
PREFIX ?= $(HOME)/.local

WORKDIR ?= $(REPO_ROOT)
TERM    ?= xterm-256color
HARNESS ?= opencode
ARGS    ?=
LOADENV := set -a; for f in "$(TOOLKIT_DIR)/.env" "$(STATE_DIR)/.env"; do [ -f "$$f" ] && . "$$f"; done; set +a;

export WORKDIR TERM LLM_REGISTRY
export LLM_STATE_DIR := $(STATE_DIR)

.PHONY: help build build-base build-node build-opencode build-pi publish check-registry install uninstall init config opencode pi shell run keys key-create key-delete clean

help:
	@sed -n '3,17p' $(MAKEFILE_LIST) | sed 's/^# \{0,1\}//'

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
	docker build -f $(TOOLKIT_DIR)/images/base/Dockerfile -t $(BASE_IMAGE) $(TOOLKIT_DIR)

build-node: build-base
	docker build -f $(TOOLKIT_DIR)/images/node/Dockerfile \
		--build-arg "BASE_REF=$(BASE_IMAGE)" -t $(NODE_IMAGE) $(TOOLKIT_DIR)

build-opencode: build-node
	docker build -f $(TOOLKIT_DIR)/images/opencode/Dockerfile \
		--build-arg "NODE_REF=$(NODE_IMAGE)" -t $(OPENCODE_IMAGE) $(TOOLKIT_DIR)

build-pi: build-node
	docker build -f $(TOOLKIT_DIR)/images/pi/Dockerfile \
		--build-arg "NODE_REF=$(NODE_IMAGE)" -t $(PI_IMAGE) $(TOOLKIT_DIR)

check-registry:
	@[ -n "$(LLM_REGISTRY)" ] || { echo "set LLM_REGISTRY, e.g. ghcr.io/<you>/" >&2; exit 1; }

publish: check-registry build
	docker push $(BASE_IMAGE)
	docker push $(NODE_IMAGE)
	docker push $(OPENCODE_IMAGE)
	docker push $(PI_IMAGE)
	@for h in base node opencode pi; do \
		docker tag "$(LLM_REGISTRY)llm-toolkit:$$h" "$(LLM_REGISTRY)llm-toolkit:$$h-$(VERSION)" && \
		docker push "$(LLM_REGISTRY)llm-toolkit:$$h-$(VERSION)"; \
	done

install:
	@PREFIX="$(PREFIX)" "$(TOOLKIT_DIR)/install.sh"

uninstall:
	@PREFIX="$(PREFIX)" "$(TOOLKIT_DIR)/uninstall.sh" $(if $(IMAGES),--images,)

init:
	@mkdir -p "$(STATE_DIR)/data"
	@if [ ! -f "$(STATE_DIR)/.env" ]; then cp "$(TOOLKIT_DIR)/template/.env.example" "$(STATE_DIR)/.env"; echo "created $(STATE_DIR)/.env"; else echo "kept existing $(STATE_DIR)/.env"; fi
	@if [ "$(STATE_DIR)" = "$(TOOLKIT_DIR)" ]; then echo "add to .gitignore: .env, /data/"; else echo "add to .gitignore: $(patsubst $(REPO_ROOT)/%,%,$(STATE_DIR))/"; fi

config:
	@mkdir -p "$(STATE_DIR)/config"
	@cp -R "$(TOOLKIT_DIR)/template/config/." "$(STATE_DIR)/config/"
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

clean:
	rm -rf "$(STATE_DIR)/data"
