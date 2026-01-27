#!/bin/bash
set -e

# Configure gateway for container networking
clawdbot config set gateway.bind lan 2>/dev/null || true
clawdbot config set gateway.port 8080 2>/dev/null || true

# Start gateway
exec clawdbot gateway --allow-unconfigured
