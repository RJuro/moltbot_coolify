#!/bin/bash
# Moltbot Gateway Entrypoint for Coolify
# Generates config and auth profiles from environment variables, then starts the gateway.
set -e

CONFIG_DIR="/home/node/.clawdbot"
CONFIG_FILE="$CONFIG_DIR/clawdbot.json"

mkdir -p "$CONFIG_DIR"

# --- Gateway authentication ---
# Password auth (preferred) or token auth
AUTH_MODE="none"
AUTH_EXTRA=""
if [ -n "${CLAWDBOT_GATEWAY_PASSWORD:-}" ]; then
  AUTH_MODE="password"
  AUTH_EXTRA="\"password\": \"${CLAWDBOT_GATEWAY_PASSWORD}\""
elif [ -n "${CLAWDBOT_GATEWAY_TOKEN:-}" ]; then
  AUTH_MODE="token"
  AUTH_EXTRA="\"token\": \"${CLAWDBOT_GATEWAY_TOKEN}\""
else
  # Auto-generate a token if nothing is set
  CLAWDBOT_GATEWAY_TOKEN=$(openssl rand -hex 32)
  export CLAWDBOT_GATEWAY_TOKEN
  AUTH_MODE="token"
  AUTH_EXTRA="\"token\": \"${CLAWDBOT_GATEWAY_TOKEN}\""
  echo "============================================"
  echo "  Auto-generated gateway token:"
  echo "  $CLAWDBOT_GATEWAY_TOKEN"
  echo "  Save this to access the Control UI!"
  echo "============================================"
fi

# --- Trusted proxies (Docker/Coolify network gateways) ---
DEFAULT_PROXIES="10.0.0.1,10.0.1.1,10.0.1.2,10.0.2.1,10.0.2.2,10.0.3.1,10.0.3.2,10.0.4.1,172.17.0.1,172.18.0.1,127.0.0.1"
TRUSTED_PROXIES="${CLAWDBOT_TRUSTED_PROXIES:-$DEFAULT_PROXIES}"
PROXIES_JSON=$(echo "$TRUSTED_PROXIES" | sed 's/,/", "/g' | sed 's/^/["/' | sed 's/$/"]/')

# --- Determine default model based on available API keys ---
DEFAULT_MODEL="anthropic/claude-sonnet-4-5"
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  DEFAULT_MODEL="anthropic/claude-sonnet-4-5"
elif [ -n "${GOOGLE_API_KEY:-}" ]; then
  DEFAULT_MODEL="google/gemini-2.5-pro"
elif [ -n "${OPENAI_API_KEY:-}" ]; then
  DEFAULT_MODEL="openai/gpt-4o"
elif [ -n "${OPENROUTER_API_KEY:-}" ]; then
  DEFAULT_MODEL="openrouter/anthropic/claude-sonnet-4"
fi
echo "Default model: $DEFAULT_MODEL"

# --- Agent safeguard defaults (prevent runaway token usage) ---
# Tool-call loop guards are always on with safe defaults.
# Context pruning is on by default (trims oversized tool outputs, not conversation).
# Context token budget and session reset are opt-in.
MAX_TOOL_ERRORS="${MOLTBOT_MAX_TOOL_ERRORS:-3}"
MAX_TOOL_CALLS="${MOLTBOT_MAX_TOOL_CALLS:-25}"
CONTEXT_PRUNING="${MOLTBOT_CONTEXT_PRUNING:-adaptive}"
echo "Agent safeguards: maxConsecutiveToolErrors=$MAX_TOOL_ERRORS, maxToolCallsPerTurn=$MAX_TOOL_CALLS, contextPruning=$CONTEXT_PRUNING"
[ -n "${MOLTBOT_CONTEXT_MESSAGES:-}" ] && echo "  contextMessages=$MOLTBOT_CONTEXT_MESSAGES"
[ -n "${MOLTBOT_CONTEXT_TOKENS:-}" ] && echo "  contextTokens=$MOLTBOT_CONTEXT_TOKENS"
[ -n "${MOLTBOT_COMPACTION_MODE:-}" ] && echo "  compaction=$MOLTBOT_COMPACTION_MODE"
[ -n "${MOLTBOT_SESSION_IDLE_MINUTES:-}" ] && echo "  session idleMinutes=$MOLTBOT_SESSION_IDLE_MINUTES"

# --- Write gateway config ---
# Deep-merge entrypoint-managed keys into existing config (preserves UI-configured settings).

# Build the entrypoint-managed config as a JSON object
MANAGED_CONFIG=$(cat <<JSONEOF
{
  "gateway": {
    "mode": "local",
    "bind": "lan",
    "port": 18789,
    "auth": {
      "mode": "${AUTH_MODE}",
      ${AUTH_EXTRA}
    },
    "trustedProxies": ${PROXIES_JSON},
    "controlUi": {
      "allowInsecureAuth": true
    }
  },
  "web": {
    "enabled": true
  },
  "agents": {
    "defaults": {
      "workspace": "/home/node/clawd",
      "model": {
        "primary": "${DEFAULT_MODEL}"
      },
      "maxConsecutiveToolErrors": ${MAX_TOOL_ERRORS},
      "maxToolCallsPerTurn": ${MAX_TOOL_CALLS},
      "contextPruning": {
        "mode": "${CONTEXT_PRUNING}"
      }
    }
  },
  "cron": {
    "isolated": true
  }
}
JSONEOF
)

# Add channels config (only if tokens are set)
if [ -n "${TELEGRAM_BOT_TOKEN:-}" ]; then
  MANAGED_CONFIG=$(echo "$MANAGED_CONFIG" | jq --arg token "$TELEGRAM_BOT_TOKEN" \
    '.channels.telegram = {
      "botToken": $token,
      "polling": {
        "retryDelayMs": 5000,
        "maxRetries": 10,
        "backoffMultiplier": 2
      }
    }')
fi
if [ -n "${DISCORD_BOT_TOKEN:-}" ]; then
  MANAGED_CONFIG=$(echo "$MANAGED_CONFIG" | jq --arg token "$DISCORD_BOT_TOKEN" \
    '.channels.discord = { "botToken": $token }')
fi

# Add optional safeguards only when explicitly set via env vars
if [ -n "${MOLTBOT_CONTEXT_MESSAGES:-}" ]; then
  MANAGED_CONFIG=$(echo "$MANAGED_CONFIG" | jq --argjson val "$MOLTBOT_CONTEXT_MESSAGES" \
    '.agents.defaults.contextMessages = $val')
fi
if [ -n "${MOLTBOT_CONTEXT_TOKENS:-}" ]; then
  MANAGED_CONFIG=$(echo "$MANAGED_CONFIG" | jq --argjson val "$MOLTBOT_CONTEXT_TOKENS" \
    '.agents.defaults.contextTokens = $val')
fi
if [ -n "${MOLTBOT_COMPACTION_MODE:-}" ]; then
  MANAGED_CONFIG=$(echo "$MANAGED_CONFIG" | jq --arg val "$MOLTBOT_COMPACTION_MODE" \
    '.agents.defaults.compaction.mode = $val')
fi
if [ -n "${MOLTBOT_SESSION_IDLE_MINUTES:-}" ]; then
  MANAGED_CONFIG=$(echo "$MANAGED_CONFIG" | jq --argjson val "$MOLTBOT_SESSION_IDLE_MINUTES" \
    '.session.reset.idleMinutes = $val')
fi

# Deep-merge: existing config is the base, entrypoint-managed keys override
if [ -f "$CONFIG_FILE" ]; then
  echo "Merging entrypoint config into existing $CONFIG_FILE"
  EXISTING=$(cat "$CONFIG_FILE")
  # jq '*' does recursive merge — managed config (right) wins on conflicts
  MERGED=$(echo "$EXISTING" "$MANAGED_CONFIG" | jq -s '.[0] * .[1]')
  echo "$MERGED" > "$CONFIG_FILE"
else
  echo "Creating new $CONFIG_FILE"
  echo "$MANAGED_CONFIG" | jq '.' > "$CONFIG_FILE"
fi
echo "Config written to $CONFIG_FILE"

# --- Build auth-profiles.json for API keys ---
# Merges env-var keys into existing profiles (preserves UI-configured keys).
AUTH_DIR="$CONFIG_DIR/agents/main/agent"
AUTH_FILE="$AUTH_DIR/auth-profiles.json"
mkdir -p "$AUTH_DIR"

ENV_PROFILES="{}"
HAS_ENV_KEYS=false

if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  ENV_PROFILES=$(echo "$ENV_PROFILES" | jq --arg key "$ANTHROPIC_API_KEY" \
    '.["anthropic:api"] = {"provider":"anthropic","mode":"api_key","apiKey":$key}')
  echo "Added Anthropic API key from env"
  HAS_ENV_KEYS=true
fi

if [ -n "${GOOGLE_API_KEY:-}" ]; then
  ENV_PROFILES=$(echo "$ENV_PROFILES" | jq --arg key "$GOOGLE_API_KEY" \
    '.["google:api"] = {"provider":"google","mode":"api_key","apiKey":$key}')
  echo "Added Google API key from env"
  HAS_ENV_KEYS=true
fi

if [ -n "${OPENAI_API_KEY:-}" ]; then
  ENV_PROFILES=$(echo "$ENV_PROFILES" | jq --arg key "$OPENAI_API_KEY" \
    '.["openai:api"] = {"provider":"openai","mode":"api_key","apiKey":$key}')
  echo "Added OpenAI API key from env"
  HAS_ENV_KEYS=true
fi

if [ -n "${OPENROUTER_API_KEY:-}" ]; then
  ENV_PROFILES=$(echo "$ENV_PROFILES" | jq --arg key "$OPENROUTER_API_KEY" \
    '.["openrouter:api"] = {"provider":"openrouter","mode":"api_key","apiKey":$key}')
  echo "Added OpenRouter API key from env"
  HAS_ENV_KEYS=true
fi

if [ "$HAS_ENV_KEYS" = true ]; then
  if [ -f "$AUTH_FILE" ]; then
    # Merge: existing profiles are base, env-var profiles override matching keys
    echo "Merging env API keys into existing $AUTH_FILE"
    EXISTING_AUTH=$(cat "$AUTH_FILE")
    MERGED_AUTH=$(echo "$EXISTING_AUTH" "$ENV_PROFILES" | jq -s '.[0] * .[1]')
    echo "$MERGED_AUTH" > "$AUTH_FILE"
  else
    echo "$ENV_PROFILES" | jq '.' > "$AUTH_FILE"
  fi
  echo "Auth profiles written to $AUTH_FILE"
elif [ ! -f "$AUTH_FILE" ]; then
  echo ""
  echo "=========================================="
  echo "WARNING: No API keys configured!"
  echo "=========================================="
  echo "Add one of these environment variables in Coolify:"
  echo "  - ANTHROPIC_API_KEY"
  echo "  - GOOGLE_API_KEY"
  echo "  - OPENAI_API_KEY"
  echo "  - OPENROUTER_API_KEY"
  echo "=========================================="
  echo ""
else
  echo "No env API keys set, keeping existing $AUTH_FILE intact"
fi

# --- Log channel tokens ---
[ -n "${TELEGRAM_BOT_TOKEN:-}" ] && echo "Telegram bot token detected"
[ -n "${DISCORD_BOT_TOKEN:-}" ] && echo "Discord bot token detected"

# --- Start gateway ---
exec moltbot gateway --bind lan --port 18789 --allow-unconfigured
