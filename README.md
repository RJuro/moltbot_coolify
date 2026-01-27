# Clawdbot on Coolify

Deploy [Clawdbot](https://molt.bot) gateway on [Coolify](https://coolify.io) with persistent configuration.

## Quick Start

1. Fork/clone this repo
2. In Coolify: **Add Resource** → **Docker Compose** → point to your repo
3. Set environment variables (see below)
4. Deploy
5. Run setup in the container terminal
6. Restart the container

## Environment Variables

Set these in Coolify's environment variables section:

| Variable | Required | Description |
|----------|----------|-------------|
| `CLAWDBOT_GATEWAY_TOKEN` | Yes | Shared secret for gateway access. Generate with: `openssl rand -hex 32` |
| `GOOGLE_API_KEY` | Yes* | Your Google AI API key from [AI Studio](https://aistudio.google.com/apikey) |
| `ANTHROPIC_API_KEY` | Yes* | Your Anthropic API key (if using Claude instead of Gemini) |

*At least one provider API key is required.

## First-Time Setup

After the first deployment, the gateway starts but isn't configured yet. You need to run setup once:

### Option 1: Coolify Terminal
1. Go to your service in Coolify
2. Click **Terminal**
3. Run: `clawdbot setup`

### Option 2: SSH + Docker
```bash
# SSH into your Coolify server
ssh user@your-server

# Find the container
docker ps | grep clawdbot

# Run setup
docker exec -it <container_name> clawdbot setup
```

After setup completes, **restart the container** in Coolify.

## Verify It's Working

```bash
curl https://your-domain.com/health
```

You should get a response (not 503).

## Architecture

```
┌─────────────────────────────────────────┐
│  Coolify                                │
│  ┌───────────────────────────────────┐  │
│  │  clawdbot-gateway container       │  │
│  │  ┌─────────────────────────────┐  │  │
│  │  │  clawdbot gateway :18789    │  │  │
│  │  └─────────────────────────────┘  │  │
│  │         │              │          │  │
│  │    ┌────┴────┐   ┌─────┴─────┐    │  │
│  │    │ config  │   │ workspace │    │  │
│  │    │ volume  │   │  volume   │    │  │
│  │    └─────────┘   └───────────┘    │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## Volumes

Two named volumes persist data across restarts and redeployments:

| Volume | Mount Point | Purpose |
|--------|-------------|---------|
| `clawdbot_state` | `/home/node/.clawdbot` | Config, sessions, agent state |
| `clawdbot_workspace` | `/home/node/clawd` | Workspace files |

## Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Node 22 image with clawdbot installed globally |
| `entrypoint.sh` | Starts the gateway process |
| `docker-compose.yaml` | Coolify-compatible compose with volumes |

## Updating Clawdbot

To update to a new version of clawdbot:

1. In Coolify, click **Redeploy** (this rebuilds the image with latest npm package)
2. The volumes preserve your config, so no re-setup needed

## Troubleshooting

### 502 Bad Gateway

This is the most common issue. Coolify's Caddy proxy can't reach the gateway inside the container.

**Cause 1: Gateway listening on localhost only**

By default, Clawdbot binds to `127.0.0.1`, which is unreachable from outside the container. Fix:

```bash
# In container terminal
clawdbot config set gateway.bind lan
# Then restart the container
```

The `entrypoint.sh` in this repo sets this automatically, but if you have an existing config volume, it may have the old setting.

**Cause 2: Coolify overwriting labels**

Coolify auto-generates Caddy labels and may override your custom ones. The key is that `{{upstreams}}` without a port defaults to port 80, but Clawdbot uses port 18789.

The `docker-compose.yaml` includes this label to fix it:
```yaml
labels:
  - "caddy_0.handle_path.0_reverse_proxy={{upstreams 18789}}"
```

**Cause 3: Container not on coolify network**

The container must be on the `coolify` network for Caddy to reach it:
```yaml
networks:
  - coolify
  - default
```

### 503 Error

The gateway process isn't running at all.

- Check logs: `docker logs <container>`
- If "Missing config" → Run `clawdbot setup` in the container, then restart
- If permission errors → Check volume permissions

### Gateway won't start

Try running with debug:
```bash
docker exec -it <container> clawdbot gateway --verbose
```

### Port mismatch after changing ports

The config is stored in a volume. If you change the port in `docker-compose.yaml` but the volume has old config, they won't match.

Fix by updating the config inside the container:
```bash
clawdbot config set gateway.port 18789
# Then restart
```

### Port already allocated

If you see `port is already allocated`, you're trying to bind to a host port that's in use. This repo uses `expose` instead of `ports` to avoid this—traffic goes through Coolify's proxy, not direct host binding.

Don't add `ports:` to the compose file unless you need direct access bypassing the proxy.

### Config lost after redeploy

Make sure you're using **Redeploy**, not delete + recreate. Named volumes persist across redeployments but not if you delete the service entirely.

### Verify gateway is listening

Inside the container:
```bash
# Check if process is running
ps aux | grep clawdbot

# Check what port it's listening on
netstat -tlnp | grep 18789

# Test locally
curl http://localhost:18789/health
```

If local curl works but external doesn't, it's a networking/proxy issue (see 502 above).

## Known Coolify Quirks

1. **Label overwriting**: Coolify generates its own Caddy labels. You must include the port explicitly in `{{upstreams 18789}}`.

2. **Network requirement**: Containers must be on the `coolify` network for the proxy to reach them.

3. **No custom Caddy config**: You can't add arbitrary Caddy config from docker-compose labels. Use the label format Coolify expects.

4. **Rebuild vs Restart**: After changing `docker-compose.yaml`, you need **Redeploy** (rebuilds image). After changing config inside the container, you only need **Restart**.

## License

MIT
