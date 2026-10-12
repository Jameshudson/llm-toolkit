# syntax=docker/dockerfile:1
#
# llm-toolkit node image — base + Node. Shared by every harness image so Node is
# stored once, not once per harness.
#
# Build (local tag) or publish (registry tag):
#   docker build -f images/node/Dockerfile --build-arg BASE_REF=llm-toolkit:base -t llm-toolkit:node .
#   docker build -f images/node/Dockerfile --build-arg BASE_REF=ghcr.io/you/llm-toolkit:base -t ghcr.io/you/llm-toolkit:node .

ARG NODE_IMAGE=node:24-bookworm-slim
ARG BASE_REF=llm-toolkit:base

FROM ${NODE_IMAGE} AS node
FROM ${BASE_REF}

# Bring in Node (and npm) from the official image — same Debian bookworm
# userspace, so the binary runs as-is.
COPY --from=node /usr/local /usr/local

RUN node --version && npm --version
