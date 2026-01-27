#!/bin/bash
set -euo pipefail

CONFIG_DIR="/home/node/.clawdbot"
CONFIG_FILES=(
  "$CONFIG_DIR/clawdbot.json"
  "$CONFIG_DIR/config.json"
)

mkdir -p "$CONFIG_DIR"

set_config() {
  local key="$1"
  local value="$2"

  if clawdbot config set "$key" "$value" >/dev/null 2>&1; then
    echo "Config set: $key=$value (via clawdbot config)"
    return 0
  fi

  for cfg in "${CONFIG_FILES[@]}"; do
    if [ -f "$cfg" ]; then
      if node - "$cfg" "$key" "$value" <<'NODE'
const fs = require("fs");
const [file, key, raw] = process.argv.slice(2);
let data;
try {
  data = JSON.parse(fs.readFileSync(file, "utf8"));
} catch (err) {
  process.exit(1);
}

const parts = key.split(".");
let obj = data;
for (let i = 0; i < parts.length - 1; i += 1) {
  const part = parts[i];
  if (!obj[part] || typeof obj[part] !== "object") obj[part] = {};
  obj = obj[part];
}

let value = raw;
if (/^-?\d+$/.test(raw)) {
  value = Number(raw);
} else if (raw === "true") {
  value = true;
} else if (raw === "false") {
  value = false;
}

obj[parts[parts.length - 1]] = value;
fs.writeFileSync(file, JSON.stringify(data, null, 2));
NODE
      then
        echo "Config set: $key=$value (patched $cfg)"
        return 0
      fi
    fi
  done

  echo "WARN: Unable to set $key (config not initialized yet)" >&2
  return 1
}

if [ -n "${CLAWDBOT_GATEWAY_PASSWORD:-}" ]; then
  set_config gateway.auth.mode password || true
elif [ -n "${CLAWDBOT_GATEWAY_TOKEN:-}" ]; then
  # Backward-compatible token auth if a token is provided.
  set_config gateway.auth.mode token || true
else
  echo "WARN: No gateway auth configured (set CLAWDBOT_GATEWAY_PASSWORD)." >&2
fi

# Configure gateway for container networking
set_config gateway.bind lan || true
set_config gateway.port 18789 || true

# Start gateway
exec clawdbot gateway --allow-unconfigured
