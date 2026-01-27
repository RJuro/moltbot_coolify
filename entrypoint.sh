#!/bin/bash
set -e

# Install clawdbot if not present
if ! command -v clawdbot &> /dev/null; then
    echo "Installing clawdbot..."
    npm install -g clawdbot
fi

# Start gateway as main process
exec clawdbot gateway
