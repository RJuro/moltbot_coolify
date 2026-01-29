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

# --- Write gateway config ---
# Always overwrite to ensure all fields are present and consistent with env vars.
cat > "$CONFIG_FILE" <<EOF
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
  "channels": {
    "telegram": {
      "dmPolicy": "open",
      "allowFrom": ["*"]
    },
    "whatsapp": {
      "dmPolicy": "open",
      "allowFrom": ["*"]
    },
    "discord": {
      "groupPolicy": "open",
      "dm": {
        "enabled": true,
        "policy": "open",
        "allowFrom": ["*"]
      },
      "guilds": {
        "*": {
          "requireMention": false
        }
      }
    }
  },
  "agents": {
    "defaults": {
      "workspace": "/home/node/clawd",
      "model": {
        "primary": "${DEFAULT_MODEL}"
      }
    }
  }
}
EOF
echo "Config written to $CONFIG_FILE"

# --- Build auth-profiles.json for API keys ---
AUTH_DIR="$CONFIG_DIR/agents/main/agent"
mkdir -p "$AUTH_DIR"

AUTH_JSON="{"
FIRST=true

if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  [ "$FIRST" = false ] && AUTH_JSON="$AUTH_JSON,"
  AUTH_JSON="$AUTH_JSON\"anthropic:api\":{\"provider\":\"anthropic\",\"mode\":\"api_key\",\"apiKey\":\"$ANTHROPIC_API_KEY\"}"
  echo "Added Anthropic API key"
  FIRST=false
fi

if [ -n "${GOOGLE_API_KEY:-}" ]; then
  [ "$FIRST" = false ] && AUTH_JSON="$AUTH_JSON,"
  AUTH_JSON="$AUTH_JSON\"google:api\":{\"provider\":\"google\",\"mode\":\"api_key\",\"apiKey\":\"$GOOGLE_API_KEY\"}"
  echo "Added Google API key"
  FIRST=false
fi

if [ -n "${OPENAI_API_KEY:-}" ]; then
  [ "$FIRST" = false ] && AUTH_JSON="$AUTH_JSON,"
  AUTH_JSON="$AUTH_JSON\"openai:api\":{\"provider\":\"openai\",\"mode\":\"api_key\",\"apiKey\":\"$OPENAI_API_KEY\"}"
  echo "Added OpenAI API key"
  FIRST=false
fi

if [ -n "${OPENROUTER_API_KEY:-}" ]; then
  [ "$FIRST" = false ] && AUTH_JSON="$AUTH_JSON,"
  AUTH_JSON="$AUTH_JSON\"openrouter:api\":{\"provider\":\"openrouter\",\"mode\":\"api_key\",\"apiKey\":\"$OPENROUTER_API_KEY\"}"
  echo "Added OpenRouter API key"
  FIRST=false
fi

AUTH_JSON="$AUTH_JSON}"

if [ "$FIRST" = false ]; then
  echo "$AUTH_JSON" > "$AUTH_DIR/auth-profiles.json"
  echo "Auth profiles written to $AUTH_DIR/auth-profiles.json"
else
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
fi

# --- Log channel tokens ---
[ -n "${TELEGRAM_BOT_TOKEN:-}" ] && echo "Telegram bot token detected"
[ -n "${DISCORD_BOT_TOKEN:-}" ] && echo "Discord bot token detected"

# --- Start gateway ---
exec moltbot gateway --bind lan --port 18789 --allow-unconfigured
