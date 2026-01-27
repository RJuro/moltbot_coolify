FROM node:20-slim

# Install curl for the install script
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Create non-root user directories
RUN mkdir -p /home/node/.clawdbot /home/node/clawd \
    && chown -R node:node /home/node

# Switch to non-root user
USER node
WORKDIR /home/node

# Install clawdbot using official install script
RUN curl -fsSL https://molt.bot/install.sh | bash

# Copy entrypoint
COPY --chown=node:node entrypoint.sh /home/node/entrypoint.sh
RUN chmod +x /home/node/entrypoint.sh

EXPOSE 18789

ENTRYPOINT ["/home/node/entrypoint.sh"]
