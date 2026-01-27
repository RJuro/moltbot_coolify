# Coolify Deployment Spec (Clawdbot)

## Recommendation
Use a proper Docker image and run it as a container in Coolify. Avoid “manual install inside a generic Linux container” for production because it is slower to boot, less reproducible, and harder to upgrade safely.

## Goals
- Automated deployment (hands‑off) on Coolify.
- Persistent state across restarts.
- Gateway exposed securely.

## Core Approach
1. **Build time install**: Install Clawdbot during image build (Dockerfile).  
2. **First‑boot onboarding**: Run `onboard --non-interactive` if no existing config is present.  
3. **Run gateway**: Start the gateway as the long‑lived process.  
4. **Persist volumes**: Mount two volumes:
   - `/home/node/.clawdbot` (config/state)
   - `/home/node/clawd` (workspace)

## Coolify Runtime Requirements
- **Port**: 18789
- **Env vars** (example):
  - `CLAWDBOT_GATEWAY_PASSWORD` (required for password auth)
  - Provider keys (e.g., `ANTHROPIC_API_KEY` or `OPENAI_API_KEY`)
- **Binding**: Use `gateway.mode=local` and bind to `lan` when serving outside the container.

## Optional: Docker Sandboxing
If you want Clawdbot’s Docker‑based sandboxing:
- The gateway container must access Docker (socket mount or privileged).
- This is a security tradeoff; skip it if you don’t need tool sandboxing.

## Suggested Compose Sketch (Coolify compatible)
```yaml
services:
  clawdbot-gateway:
    build: .
    command: ["gateway"]
    ports:
      - "18789:18789"
    environment:
      - CLAWDBOT_GATEWAY_PASSWORD=${CLAWDBOT_GATEWAY_PASSWORD}
    volumes:
      - clawdbot_state:/home/node/.clawdbot
      - clawdbot_workspace:/home/node/clawd

  # Optional one-off onboarding service (manual trigger)
  clawdbot-cli:
    build: .
    command:
      - "onboard"
      - "--non-interactive"
      - "--mode"
      - "local"
      - "--gateway-port"
      - "18789"
      - "--gateway-bind"
      - "lan"
      - "--skip-skills"
    environment:
      - CLAWDBOT_GATEWAY_PASSWORD=${CLAWDBOT_GATEWAY_PASSWORD}
    volumes:
      - clawdbot_state:/home/node/.clawdbot
      - clawdbot_workspace:/home/node/clawd

volumes:
  clawdbot_state:
  clawdbot_workspace:
```

## Open Decisions
- Which provider to target for non‑interactive onboarding (Anthropic/OpenAI/etc.)?
- Do we include a manual onboarding service as a fallback?
- Do we enable Docker sandboxing (requires Docker access)?
