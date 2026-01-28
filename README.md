# Clawdbot on Coolify

> **This is a personal template by [@RJuro](https://github.com/RJuro).** It assumes familiarity with Docker, Coolify, and command-line tools. If you're not comfortable debugging container networking issues, this setup may not be for you.

Deploy [Clawdbot](https://molt.bot) gateway on [Coolify](https://coolify.io) with persistent configuration.

## Quick Start

1. Fork this repo
2. In Coolify: **Add Resource** → **Docker Compose** → point to your fork
3. Set environment variables (see below)
4. Deploy
5. Run `clawdbot setup` in the container terminal
6. Restart the container

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `CLAWDBOT_GATEWAY_PASSWORD` | Yes | Gateway password. Generate: `openssl rand -base64 32` |
| `GOOGLE_API_KEY` | Yes* | Google AI API key |
| `ANTHROPIC_API_KEY` | Yes* | Anthropic API key |

*At least one provider key required.

## First-Time Setup

After deployment, run setup once:

```bash
# In Coolify terminal, or via SSH:
docker exec -it <container_name> clawdbot setup
```

Then restart the container.

## Volumes

| Volume | Path | Purpose |
|--------|------|---------|
| `clawdbot_state` | `/home/node/.clawdbot` | Config and sessions |
| `clawdbot_workspace` | `/home/node/clawd` | Workspace files |

## Known Issues

**Gateway frontend access**: The bot/API works but the web UI may have access issues due to container networking or missing permissions. The `gateway.bind` is set to `lan` which should work, but Coolify's proxy configuration can be finicky.

If you get 502 errors:
- Verify the gateway is listening: `docker exec <container> curl localhost:18789/health`
- Check that `gateway.bind` is set to `lan` (not `localhost`)
- Ensure the container is on the `coolify` network

## Troubleshooting

**502 Bad Gateway**: Gateway not reachable from proxy. Check network config and port labels.

**503 Error**: Gateway process not running. Check logs with `docker logs <container>`.

**Config lost**: Use **Redeploy**, not delete + recreate. Volumes persist across redeployments.
