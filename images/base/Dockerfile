# syntax=docker/dockerfile:1
#
# llm-toolkit base image — OS toolchain only. No Node, no harness.
#
# Harness images build FROM this and add Node plus their harness. A repo's own
# Dockerfile can build FROM base (no Node) or FROM a harness image. See the
# README.
#
# Build:
#   docker build -f images/base/Dockerfile -t llm-toolkit:base .

FROM debian:bookworm-slim

# Toolchain. The harnesses shell out to git, ripgrep, and a pager; curl, jq,
# ssh, and the archive tools round out day-to-day work. libstdc++6 backs the
# Node binary that harness images copy in.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      git \
      jq \
      less \
      libstdc++6 \
      openssh-client \
      ripgrep \
      tar \
      unzip \
      xz-utils \
 && rm -rf /var/lib/apt/lists/*

# Generic entrypoint: prepares the workspace and SSH agent, runs entrypoint
# hooks, then execs the command. Harness-specific setup lives in harness images.
COPY images/base/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
