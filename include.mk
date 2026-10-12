# llm-toolkit — optional make sugar for a project repo.
#
# Add one line to your Makefile:
#   -include $(HOME)/.local/share/llm-toolkit/include.mk
# (or copy this file in and include it). Requires the llm CLI on PATH — install
# it from the llm-toolkit repo with `make install`.
#
# Then, from the repo root:
#   make llm-opencode
#   make llm-pi
#   make llm-shell
#   make llm-run HARNESS=pi ARGS="summarise this repo"
#   make llm-keys

LLM    ?= llm
OR_KEY ?= or-key

.PHONY: llm-opencode llm-pi llm-shell llm-run llm-keys

llm-opencode: ; @$(LLM) opencode
llm-pi:       ; @$(LLM) pi
llm-shell:    ; @$(LLM) shell
llm-run:      ; @$(LLM) run --harness $(HARNESS) $(ARGS)
llm-keys:     ; @$(OR_KEY) list
