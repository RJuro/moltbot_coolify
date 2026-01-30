# OpenClaw on Coolify

> **Personal template by [@RJuro](https://github.com/RJuro).** Assumes familiarity with Docker, Coolify, and command-line tools.

Deploy the [OpenClaw](https://openclaw.ai) gateway on [Coolify](https://coolify.io) with persistent configuration, auto-generated auth, and API key management.

Uses the [`openclaw@latest`](https://www.npmjs.com/package/openclaw) npm package (the official release channel by steipete). The project was formerly known as "clawdbot" → "moltbot" → "openclaw" — legacy `CLAWDBOT_` env var prefixes are still supported.

## Quick Start

1. Fork this repo
2. In Coolify: **Add Resource** → **Docker Compose** → point to your fork
3. Set environment variables (see below)
4. Deploy

No manual setup step needed — the entrypoint auto-generates config and auth profiles from your environment variables.

## Environment Variables

Set these in your Coolify resource settings.

### Authentication (auto-generated if omitted)

| Variable | Required | Description |
|----------|----------|-------------|
| `OPENCLAW_GATEWAY_PASSWORD` | Recommended | Gateway password for Control UI access |
| `OPENCLAW_GATEWAY_TOKEN` | No | Token auth (alternative to password) |

If neither is set, a random token is auto-generated and printed in container logs. Legacy `CLAWDBOT_GATEWAY_PASSWORD` / `CLAWDBOT_GATEWAY_TOKEN` are also accepted.

### AI Provider Keys (at least one required)

| Variable | Provider |
|----------|----------|
| `ANTHROPIC_API_KEY` | Anthropic (Claude) |
| `GOOGLE_API_KEY` | Google AI (Gemini) |
| `OPENAI_API_KEY` | OpenAI (GPT) |
| `OPENROUTER_API_KEY` | OpenRouter (multi-provider) |

### Channel Integrations (optional)

| Variable | Channel |
|----------|---------|
| `TELEGRAM_BOT_TOKEN` | Telegram |
| `DISCORD_BOT_TOKEN` | Discord |

### Token Usage Safeguards

These settings are optional overrides; OpenClaw defaults are used when unset.

| Variable | Default | Description |
|----------|---------|-------------|
| `MOLTBOT_CONTEXT_PRUNING` | *(unset)* | Prunes oversized tool outputs from context (not conversation). Modes vary by OpenClaw version (e.g., `adaptive`, `aggressive`, `cache-ttl`, or `off`) |
| `MOLTBOT_CONTEXT_TOKENS` | *(unset)* | Hard cap on context window in tokens (e.g., `100000` for 100K). Prevents sessions from growing to 1M+ tokens |
| `MOLTBOT_COMPACTION_MODE` | *(unset)* | Context compaction strategy — `safeguard` for adaptive chunking with progressive fallback and retries |
| `MOLTBOT_SESSION_IDLE_MINUTES` | *(unset)* | Auto-reset session after N minutes of inactivity (e.g., `120`). Starts a fresh context on next message |

**What these protect against:**
- **Context dragging**: Oversized tool outputs get carried forward on every turn, burning tokens. Override pruning mode if needed.
- **Context overflow at 1M tokens**: Sessions grow until the model returns "prompt too large" errors. Set `CONTEXT_TOKENS=100000` to cap the window well below the model limit.
- **Telegram polling storms**: Telegram config includes retry backoff (5s base, 2x multiplier, max 10 retries) to prevent tight reconnect loops.
- **Stale sessions**: Without `SESSION_IDLE_MINUTES`, a session can accumulate days of history. Setting it to e.g. `120` resets after 2 hours idle.

**Note:** Config and auth profiles are **merged** on redeploy, not overwritten. Keys configured through the OpenClaw Control UI survive container restarts.

## Architecture

- **Single service**: `openclaw-gateway` on port 18789
- **Health check**: `curl http://localhost:18789/health` (30s interval, 60s startup grace)
- **Proxy labels**: Both Traefik and Caddy labels included for Coolify compatibility
- **Volumes**: Config persists across redeployments
- **Graceful shutdown**: 30s stop grace period prevents AbortError crashes

## Volumes

| Volume | Container Path | Purpose |
|--------|---------------|---------|
| `openclaw_state` | `/home/node/.openclaw` | Config, sessions, auth profiles |
| `openclaw_workspace` | `/home/node/.openclaw/workspace` | Workspace files |

## How It Works

The `entrypoint.sh` script:
1. Migrates legacy `clawdbot.json` → `openclaw.json` if needed
2. Deep-merges gateway config from env vars into existing config (preserves UI settings)
3. Merges API key profiles (preserves UI-configured keys)
4. Configures `gateway.bind=lan` so the gateway is reachable from Coolify's proxy network
5. Starts the gateway with `openclaw gateway --allow-unconfigured`

## Troubleshooting

**502 Bad Gateway**: Gateway not reachable from proxy.
- Check health: `docker exec <container> curl localhost:18789/health`
- Verify the container is on the `coolify` network
- Ensure `gateway.bind` is `lan` (handled automatically by entrypoint)

**503 Error**: Gateway process crashed. Check logs: `docker logs <container>`

**Config lost after redeploy**: Use **Redeploy** in Coolify, not delete + recreate. Named volumes persist across redeployments. Config is backed up to `openclaw.json.bak` before each merge.

**No API keys warning**: Set at least one provider key (ANTHROPIC_API_KEY, GOOGLE_API_KEY, etc.) in Coolify environment variables.

**Telegram disconnects / timeouts**: Node 22's built-in fetch has IPv6/IPv4 DNS issues. The Dockerfile sets `NODE_OPTIONS="--dns-result-order=ipv4first"` as mitigation. If problems persist, the container will auto-restart (`restart: unless-stopped`) and Telegram polling retries with exponential backoff.

**Gateway crash-loops**: If a bad config change via chat bricks the bot, the entrypoint restores from `openclaw.json.bak` on next restart. Entrypoint-managed keys (auth, bind, port, safeguards) always override on merge, preventing lockouts.

**High token costs**: Set `MOLTBOT_CONTEXT_TOKENS=100000` to cap context well below the model limit. If you need to adjust pruning, set `MOLTBOT_CONTEXT_PRUNING`. Use `/status` in chat to check current token usage.

**Migration from moltbot/clawdbot**: The entrypoint auto-migrates `clawdbot.json` → `openclaw.json`. Legacy `CLAWDBOT_` env var prefixes are still supported. If upgrading an existing deployment, your existing `moltbot_state` volume data will be picked up — just update the volume mount path in Coolify to `/home/node/.openclaw`.
