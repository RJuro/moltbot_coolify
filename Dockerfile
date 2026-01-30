# OpenClaw Gateway - Optimized for Coolify Deployment
# https://github.com/openclaw/openclaw
#
# Formerly known as clawdbot → moltbot → openclaw.
# Uses openclaw@latest from npm (the official release channel by steipete).

# Use full bookworm (not slim) — matches the official OpenClaw Dockerfile.
# The slim variant strips Python, which breaks OpenClaw's skills system.
FROM node:22-bookworm

LABEL org.opencontainers.image.title="OpenClaw Gateway"
LABEL org.opencontainers.image.description="Personal AI Assistant - Gateway Service"
LABEL org.opencontainers.image.source="https://github.com/openclaw/openclaw"

# Install system dependencies:
#   git              - required by openclaw npm deps that reference git repos
#   curl             - health checks
#   python3-pip/venv - openclaw skills install Python packages at runtime
#   jq/openssl       - config generation in entrypoint
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    openssl \
    ca-certificates \
    python3-pip \
    python3-venv \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user directories for config and workspace persistence
RUN mkdir -p /home/node/.openclaw /home/node/.openclaw/workspace \
    && chown -R node:node /home/node

# Install openclaw globally
RUN npm install -g openclaw@latest

# Switch to non-root user
USER node
WORKDIR /home/node

# Copy entrypoint
COPY --chown=node:node entrypoint.sh /home/node/entrypoint.sh
RUN chmod +x /home/node/entrypoint.sh

# Environment defaults
ENV NODE_ENV=production
ENV OPENCLAW_STATE_DIR=/home/node/.openclaw
# Fix Node 22 undici DNS resolution issues with Telegram API and other services.
# Node 22's built-in fetch (undici) has IPv6/IPv4 issues causing timeouts and crashes.
# See: github.com/openclaw/openclaw/issues/2436, /issues/3005
ENV NODE_OPTIONS="--dns-result-order=ipv4first"
# Allow pip installs without venv (Debian PEP 668 restriction).
# Running as non-root 'node' user, pip auto-installs to ~/.local.
ENV PIP_BREAK_SYSTEM_PACKAGES=1
ENV PATH="/home/node/.local/bin:${PATH}"

EXPOSE 18789

# Health check so Coolify knows the gateway is ready
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:18789/health || exit 1

ENTRYPOINT ["/home/node/entrypoint.sh"]
