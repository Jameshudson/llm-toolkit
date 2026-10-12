# syntax=docker/dockerfile:1
#
# llm-toolkit — pi harness image (node + pi).
#
# Build (local tag) or publish (registry tag):
#   docker build -f images/pi/Dockerfile --build-arg NODE_REF=llm-toolkit:node -t llm-toolkit:pi .

ARG NODE_REF=llm-toolkit:node
FROM ${NODE_REF}

# Pinned deliberately; Renovate does not manage this file.
ARG PI_VERSION=1.1.0

# Pi installs with --ignore-scripts per its docs.
RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent@${PI_VERSION} \
 && npm cache clean --force \
 && pi --version

# Pi-specific entrypoint hook (config seeding); base stays harness-agnostic.
COPY images/pi/entrypoint.d/ /etc/llm-toolkit/entrypoint.d/
RUN chmod +x /etc/llm-toolkit/entrypoint.d/*.sh

CMD ["pi"]
