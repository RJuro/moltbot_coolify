# Moltbot Gateway - Optimized for Coolify Deployment
# https://github.com/moltbot/moltbot
#
# Uses moltbot@beta from npm (the official package by steipete).
# The beta tag tracks the active development channel — the @latest tag
# on npm is currently a placeholder and should NOT be used.

FROM node:22-bookworm-slim

LABEL org.opencontainers.image.title="Moltbot Gateway"
LABEL org.opencontainers.image.description="Personal AI Assistant - Gateway Service"
LABEL org.opencontainers.image.source="https://github.com/moltbot/moltbot"

# Install system dependencies needed for health checks and config management
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    jq \
    openssl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user directories for config and workspace persistence
RUN mkdir -p /home/node/.clawdbot /home/node/clawd \
    && chown -R node:node /home/node

# Install moltbot globally (beta channel = real releases)
RUN npm install -g moltbot@beta

# Switch to non-root user
USER node
WORKDIR /home/node

# Copy entrypoint
COPY --chown=node:node entrypoint.sh /home/node/entrypoint.sh
RUN chmod +x /home/node/entrypoint.sh

# Environment defaults
ENV NODE_ENV=production
ENV CLAWDBOT_STATE_DIR=/home/node/.clawdbot
ENV CLAWDBOT_WORKSPACE=/home/node/clawd

EXPOSE 18789

# Health check so Coolify knows the gateway is ready
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:18789/health || exit 1

ENTRYPOINT ["/home/node/entrypoint.sh"]
