# 🦞 OpenClaw (Clawdbot) for Coolify

Deploy your own personal AI assistant with Claude automation in Coolify.

## Features

- **Self-hosted AI Assistant**: Run OpenClaw on your own infrastructure
- **Claude Automation**: Pre-configured with Claude Code CLI for automation tasks
- **Multi-channel Support**: Connect to Telegram, Discord, Slack, WhatsApp, and more
- **Gateway Exposed**: Ready for external configuration via web dashboard
- **Coolify Optimized**: Traefik labels, health checks, and proper logging

## Quick Start (Coolify)

### Option 1: Git Repository Deployment

1. Fork or clone this repository
2. In Coolify, create a new **Docker Compose** service
3. Point to your repository URL
4. Add environment variables (see below)
5. Deploy!

### Option 2: Manual File Upload

1. Download all files from this repository
2. In Coolify, create a new **Docker Compose** service
3. Upload `docker-compose.yml`, `Dockerfile`, and scripts
4. Configure environment variables
5. Deploy!

## Required Environment Variables

Set these in your Coolify service settings:

| Variable | Description | Required |
|----------|-------------|----------|
| `OPENCLAW_GATEWAY_TOKEN` | Authentication token for the gateway | ✅ Yes |
| `ANTHROPIC_API_KEY` | Claude API key | ✅ Yes* |
| `OPENAI_API_KEY` | OpenAI API key | ⚡ Alternative |
| `OPENROUTER_API_KEY` | OpenRouter API key | ⚡ Alternative |

*At least one AI provider API key is required.

### Generate Gateway Token

```bash
openssl rand -hex 32
```

## Optional Environment Variables

### Model Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENCLAW_MODEL` | `anthropic/claude-sonnet-4-5` | AI model to use |
| `GATEWAY_PORT` | `18789` | Gateway port |
| `GATEWAY_VERBOSE` | `false` | Enable verbose logging |

### Channel Tokens

| Variable | Description |
|----------|-------------|
| `TELEGRAM_BOT_TOKEN` | Telegram bot token from @BotFather |
| `DISCORD_BOT_TOKEN` | Discord bot token |
| `SLACK_BOT_TOKEN` | Slack bot token (xoxb-...) |
| `SLACK_APP_TOKEN` | Slack app token (xapp-...) |

### Feature Toggles

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_BROWSER` | `false` | Enable browser automation |
| `ENABLE_SANDBOX` | `false` | Enable sandboxed tool execution |
| `INSTALL_CLAUDE_CODE` | `true` | Install Claude Code CLI |

## Accessing the Dashboard

Once deployed, access your OpenClaw dashboard at:

```
https://your-domain/?token=YOUR_GATEWAY_TOKEN
```

Or via Coolify's exposed port:

```
http://your-server-ip:18789/?token=YOUR_GATEWAY_TOKEN
```

## Gateway Configuration

After deployment, you can further configure OpenClaw through:

1. **Web Dashboard**: Access at your configured domain
2. **CLI Commands**: Use the `openclaw-cli` service
3. **Configuration File**: Mounted at `/home/node/.openclaw/openclaw.json` (new) or `/home/node/.clawdbot/clawdbot.json` (legacy)

### Using the CLI

```bash
# Run CLI commands
docker compose --profile cli run --rm openclaw-cli <command>

# Examples:
docker compose --profile cli run --rm openclaw-cli status
docker compose --profile cli run --rm openclaw-cli channels list
docker compose --profile cli run --rm openclaw-cli doctor
```

## Adding Messaging Channels

> **Note**: Channels are automatically enabled when you provide their tokens. Simply add the environment variable and restart the service.

### Telegram

1. Create a bot via [@BotFather](https://t.me/BotFather)
2. Add `TELEGRAM_BOT_TOKEN` to Coolify environment
3. Redeploy or restart the service
4. ✅ Telegram channel will be automatically enabled

### Discord

1. Create a bot in [Discord Developer Portal](https://discord.com/developers/applications)
2. Get the bot token
3. Add `DISCORD_BOT_TOKEN` to Coolify environment
4. Invite bot to your server
5. ✅ Discord channel will be automatically enabled

### Slack

1. Create a Slack App in [Slack API](https://api.slack.com/apps)
2. Enable Socket Mode
3. Add `SLACK_BOT_TOKEN` and `SLACK_APP_TOKEN` to Coolify environment
4. ✅ Slack channel will be automatically enabled

### WhatsApp

After deployment, link WhatsApp via CLI:

```bash
docker compose --profile cli run --rm openclaw-cli channels login
```

Scan the QR code with your WhatsApp app.

## Claude Automation

This deployment includes Claude Code CLI for automation. The workspace is pre-configured at `/home/node/clawd` with:

- `AGENTS.md`: Agent capabilities and configuration
- `SOUL.md`: Personality and behavior settings

### Customizing the Agent

Mount your custom files or edit through the dashboard:

```bash
# Access the workspace
docker exec -it openclaw-gateway bash
cd /home/node/clawd
```

## Volume Mounts

| Volume | Path | Purpose |
|--------|------|---------|
| `moltbot-config` | `/home/node/.clawdbot` | Legacy Clawdbot configuration (backward compatibility) |
| `openclaw-config` | `/home/node/.openclaw` | OpenClaw configuration & credentials |
| `moltbot-workspace` | `/home/node/clawd` | Agent workspace (persisted) |
| `moltbot-claude` | `/home/node/.claude` | Claude Code credentials (persisted) |

> **Note**: Both legacy `.clawdbot` and new `.openclaw` paths are mounted to ensure backward compatibility and smooth migration. The `moltbot-*` volume names preserve existing data from the MoltBot → OpenClaw migration.

## Health Check

The container includes a health check endpoint:

```bash
curl http://your-server:18789/health
```

## Traefik Configuration

The docker-compose includes Traefik labels for automatic HTTPS:

- HTTP to HTTPS redirect
- WebSocket support
- Let's Encrypt certificates

Set `DOMAIN` environment variable to your domain.

## Troubleshooting

### Check Logs

```bash
docker compose logs -f openclaw-gateway
```

### Check Health

```bash
docker compose exec openclaw-gateway /usr/local/bin/healthcheck.sh
```

### Run Doctor

```bash
docker compose --profile cli run --rm openclaw-cli doctor
```

### Reset Configuration

```bash
# Remove volumes and redeploy
docker compose down -v
docker compose up -d
```

## Security Considerations

1. **Gateway Token**: Always use a strong, unique token
2. **HTTPS**: Enable Traefik TLS for production
3. **API Keys**: Store securely in Coolify's encrypted environment
4. **Network**: Consider limiting exposed ports

## Resources

- [OpenClaw Documentation](https://docs.clawd.bot)
- [GitHub Repository](https://github.com/openclaw/openclaw)
- [Discord Community](https://discord.gg/clawd)

## License

MIT License - See [LICENSE](https://github.com/openclaw/openclaw/blob/main/LICENSE)

---

🦞 **EXFOLIATE! EXFOLIATE!** 🦞
