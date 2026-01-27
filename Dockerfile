FROM node:22

# Create non-root user directories
RUN mkdir -p /home/node/.clawdbot /home/node/clawd \
    && chown -R node:node /home/node

# Install clawdbot globally (as root)
RUN npm install -g clawdbot

# Switch to non-root user
USER node
WORKDIR /home/node

# Copy entrypoint
COPY --chown=node:node entrypoint.sh /home/node/entrypoint.sh
RUN chmod +x /home/node/entrypoint.sh

EXPOSE 18789

ENTRYPOINT ["/home/node/entrypoint.sh"]
