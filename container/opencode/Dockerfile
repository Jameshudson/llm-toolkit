# syntax=docker/dockerfile:1
#
# llm-toolkit — opencode harness image (node + opencode).
#
# Build (local tag) or publish (registry tag):
#   docker build -f container/opencode/Dockerfile --build-arg NODE_REF=llm-toolkit:node -t llm-toolkit:opencode .

ARG NODE_REF=llm-toolkit:node
FROM ${NODE_REF}

# Pinned deliberately; Renovate does not manage this file.
ARG OPENCODE_VERSION=1.19.0

# The npm shim fetches the platform binary in its postinstall, so scripts stay on.
RUN npm install -g opencode-ai@${OPENCODE_VERSION} \
 && npm cache clean --force \
 && opencode --version

CMD ["opencode"]
