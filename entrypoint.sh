#!/bin/bash
set -e

# ============================================================================
# MoltBot (Clawdbot) Entrypoint for Coolify
# Handles automatic configuration and Claude automation setup
# ============================================================================

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║        🦞 MoltBot (Clawdbot) - Personal AI Assistant                 ║"
echo "║             Coolify Self-Hosted Deployment                           ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"

# Configuration paths
CONFIG_DIR="${CLAWDBOT_HOME:-/home/node/.clawdbot}"
WORKSPACE_DIR="${WORKSPACE_DIR:-/home/node/clawd}"
CONFIG_FILE="${CONFIG_DIR}/clawdbot.json"

# Ensure directories exist
mkdir -p "${CONFIG_DIR}" "${WORKSPACE_DIR}" "${CONFIG_DIR}/credentials"

# ============================================================================
# Generate configuration from environment variables
# ============================================================================
generate_config() {
    echo "📝 Generating configuration..."
    
    # Start with base config (using new schema: agents.defaults.*)
    cat > "${CONFIG_FILE}" << 'BASECONFIG'
{
  "gateway": {
    "bind": "lan",
    "port": 18789,
    "auth": {
      "mode": "token"
    },
    "controlUi": {
      "allowInsecureAuth": true
    }
  },
  "agents": {
    "defaults": {
      "workspace": "/home/node/clawd",
      "model": {
        "primary": "anthropic/claude-sonnet-4-5"
      }
    }
  }
}
BASECONFIG

    # Update config with environment variables using jq
    local temp_config=$(mktemp)
    
    # Gateway token
    if [ -n "${CLAWDBOT_GATEWAY_TOKEN}" ]; then
        jq --arg token "${CLAWDBOT_GATEWAY_TOKEN}" \
           '.gateway.auth.token = $token' \
           "${CONFIG_FILE}" > "${temp_config}" && mv "${temp_config}" "${CONFIG_FILE}"
    fi
    
    # Model configuration (new schema: agents.defaults.model.primary)
    if [ -n "${CLAWDBOT_MODEL}" ]; then
        jq --arg model "${CLAWDBOT_MODEL}" \
           '.agents.defaults.model.primary = $model' \
           "${CONFIG_FILE}" > "${temp_config}" && mv "${temp_config}" "${CONFIG_FILE}"
    fi
    
    # Anthropic API Key
    if [ -n "${ANTHROPIC_API_KEY}" ]; then
        jq --arg key "${ANTHROPIC_API_KEY}" \
           '.providers.anthropic.apiKey = $key' \
           "${CONFIG_FILE}" > "${temp_config}" && mv "${temp_config}" "${CONFIG_FILE}"
    fi
    
    # OpenAI API Key
    if [ -n "${OPENAI_API_KEY}" ]; then
        jq --arg key "${OPENAI_API_KEY}" \
           '.providers.openai.apiKey = $key' \
           "${CONFIG_FILE}" > "${temp_config}" && mv "${temp_config}" "${CONFIG_FILE}"
    fi
    
    # OpenRouter API Key
    if [ -n "${OPENROUTER_API_KEY}" ]; then
        jq --arg key "${OPENROUTER_API_KEY}" \
           '.providers.openrouter.apiKey = $key' \
           "${CONFIG_FILE}" > "${temp_config}" && mv "${temp_config}" "${CONFIG_FILE}"
    fi
    
    # Telegram bot token
    if [ -n "${TELEGRAM_BOT_TOKEN}" ]; then
        jq --arg token "${TELEGRAM_BOT_TOKEN}" \
           '.channels.telegram.botToken = $token' \
           "${CONFIG_FILE}" > "${temp_config}" && mv "${temp_config}" "${CONFIG_FILE}"
    fi
    
    # Discord bot token
    if [ -n "${DISCORD_BOT_TOKEN}" ]; then
        jq --arg token "${DISCORD_BOT_TOKEN}" \
           '.channels.discord.token = $token' \
           "${CONFIG_FILE}" > "${temp_config}" && mv "${temp_config}" "${CONFIG_FILE}"
    fi
    
    # Slack tokens
    if [ -n "${SLACK_BOT_TOKEN}" ] && [ -n "${SLACK_APP_TOKEN}" ]; then
        jq --arg bot "${SLACK_BOT_TOKEN}" --arg app "${SLACK_APP_TOKEN}" \
           '.channels.slack.botToken = $bot | .channels.slack.appToken = $app' \
           "${CONFIG_FILE}" > "${temp_config}" && mv "${temp_config}" "${CONFIG_FILE}"
    fi
    
    # Enable browser if requested
    if [ "${ENABLE_BROWSER}" = "true" ]; then
        jq '.browser.enabled = true | .browser.headless = true' \
           "${CONFIG_FILE}" > "${temp_config}" && mv "${temp_config}" "${CONFIG_FILE}"
    fi
    
    # Enable sandboxing if requested
    if [ "${ENABLE_SANDBOX}" = "true" ]; then
        jq '.agents.defaults.sandbox.mode = "non-main"' \
           "${CONFIG_FILE}" > "${temp_config}" && mv "${temp_config}" "${CONFIG_FILE}"
    fi
    
    echo "✅ Configuration generated at ${CONFIG_FILE}"
}

# ============================================================================
# Setup Claude Code integration for automation
# ============================================================================
setup_claude_automation() {
    echo "🤖 Setting up Claude automation..."
    
    # Check if Claude Code CLI is installed
    if command -v claude &> /dev/null; then
        echo "✅ Claude Code CLI is available"
        
        # Create automation workspace
        mkdir -p "${WORKSPACE_DIR}/automation"
        
        # Create AGENTS.md for workspace configuration
        if [ ! -f "${WORKSPACE_DIR}/AGENTS.md" ]; then
            cat > "${WORKSPACE_DIR}/AGENTS.md" << 'AGENTSMD'
# MoltBot Agent Workspace

This workspace is configured for automated AI assistance via MoltBot.

## Capabilities

- Multi-channel messaging (WhatsApp, Telegram, Discord, Slack, etc.)
- Browser automation and web scraping
- File management and code execution
- Scheduled tasks and cron jobs
- Memory and context persistence

## Skills

The agent has access to:
- `bash` - Execute shell commands
- `read`/`write`/`edit` - File operations
- `browser` - Web automation
- `sessions_*` - Multi-agent coordination

## Custom Instructions

Add your custom instructions here to personalize the assistant behavior.
AGENTSMD
            echo "✅ Created AGENTS.md workspace configuration"
        fi
        
        # Create SOUL.md for personality configuration
        if [ ! -f "${WORKSPACE_DIR}/SOUL.md" ]; then
            cat > "${WORKSPACE_DIR}/SOUL.md" << 'SOULMD'
# MoltBot Soul Configuration

You are MoltBot, a helpful personal AI assistant running in a self-hosted environment.

## Personality

- Helpful and proactive
- Privacy-conscious (all data stays local)
- Technical but approachable
- Efficient and action-oriented

## Guidelines

1. Respect user privacy - all processing is local
2. Be concise but thorough
3. Offer to help with follow-up tasks
4. Remember context across conversations

## Channels

You can communicate through multiple channels:
- Direct messages (priority)
- Group chats (respond when mentioned)
- WebChat interface
SOULMD
            echo "✅ Created SOUL.md personality configuration"
        fi
        
    else
        echo "ℹ️ Claude Code CLI not installed, skipping automation setup"
    fi
}

# ============================================================================
# Initialize or update gateway token
# ============================================================================
init_gateway_token() {
    if [ -z "${CLAWDBOT_GATEWAY_TOKEN}" ]; then
        # Generate a new token if not provided
        export CLAWDBOT_GATEWAY_TOKEN=$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | xxd -p)
        echo "🔑 Generated new gateway token: ${CLAWDBOT_GATEWAY_TOKEN:0:8}..."
        echo "   Store this token securely for future access!"
    else
        echo "🔑 Using provided gateway token: ${CLAWDBOT_GATEWAY_TOKEN:0:8}..."
    fi
}

# ============================================================================
# Wait for configuration to be ready
# ============================================================================
wait_for_config() {
    local max_attempts=5
    local attempt=0
    
    while [ ! -f "${CONFIG_FILE}" ] && [ $attempt -lt $max_attempts ]; do
        echo "⏳ Waiting for configuration..."
        sleep 2
        ((attempt++))
    done
    
    if [ ! -f "${CONFIG_FILE}" ]; then
        echo "⚠️ Configuration not found, generating default..."
        generate_config
    fi
}

# ============================================================================
# Display connection information
# ============================================================================
show_connection_info() {
    local hostname=$(hostname -i 2>/dev/null || echo "localhost")
    
    echo ""
    echo "════════════════════════════════════════════════════════════════════════"
    echo "🌐 MoltBot Gateway is starting..."
    echo "════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "📡 Gateway URL:     http://${hostname}:18789"
    echo "🔐 Dashboard URL:   http://${hostname}:18789/?token=${CLAWDBOT_GATEWAY_TOKEN}"
    echo ""
    echo "📱 Coolify Access:"
    echo "   Configure your Coolify service to expose port 18789"
    echo "   Use the dashboard URL with token for web access"
    echo ""
    echo "🔧 API Endpoints:"
    echo "   WebSocket:       ws://${hostname}:18789"
    echo "   Health Check:    http://${hostname}:18789/health"
    echo ""
    echo "════════════════════════════════════════════════════════════════════════"
    echo ""
}

# ============================================================================
# Main execution
# ============================================================================
main() {
    # Initialize token
    init_gateway_token
    
    # Generate or update configuration
    generate_config
    
    # Setup Claude automation
    setup_claude_automation
    
    # Show connection info
    show_connection_info
    
    # Start the gateway
    echo "🚀 Starting MoltBot Gateway..."
    exec clawdbot gateway \
        --port "${GATEWAY_PORT:-18789}" \
        --token "${CLAWDBOT_GATEWAY_TOKEN}" \
        ${GATEWAY_VERBOSE:+--verbose}
}

# Run main function
main "$@"
