#!/bin/bash
set -e

# Add common install locations to PATH
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

# Start gateway as main process
exec clawdbot gateway
