#!/bin/bash
set -e

# ============================================================================
# OpenClaw (Clawdbot) Entrypoint for Coolify
# Handles automatic configuration and Claude automation setup
# ============================================================================

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║        🦞 OpenClaw (Clawdbot) - Personal AI Assistant                ║"
echo "║             Coolify Self-Hosted Deployment                           ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"

# Configuration paths
CONFIG_DIR="${OPENCLAW_HOME:-/home/node/.openclaw}"
WORKSPACE_DIR="${WORKSPACE_DIR:-/home/node/clawd}"
CONFIG_FILE="${CONFIG_DIR}/openclaw.json"

# Set up D-Bus and systemd environment for openclaw gateway
# See: https://github.com/openclaw/openclaw/issues/1818
# Use home directory since /run requires root privileges
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-${HOME}/.local/run}"
mkdir -p "${XDG_RUNTIME_DIR}"
chmod 700 "${XDG_RUNTIME_DIR}"

# Ensure directories exist with correct ownership
mkdir -p "${CONFIG_DIR}" "${WORKSPACE_DIR}" "${CONFIG_DIR}/credentials" "${HOME}/.npm"

# Fix npm cache permissions if they exist (handles volume persistence)
if [ -d "${HOME}/.npm" ]; then
    # Only try to fix if we detect permission issues
    if [ ! -w "${HOME}/.npm" ] 2>/dev/null; then
        echo "⚠️  Detected npm cache permission issues, attempting to fix..."
        # This will fail silently if we don't have permissions, which is fine
        chown -R "$(id -u):$(id -g)" "${HOME}/.npm" 2>/dev/null || true
    fi
fi

# ============================================================================
# Generate configuration from environment variables
# ============================================================================
generate_config() {
    echo "📝 Generating configuration..."
    
    # Start with base config (using new schema: agents.defaults.*)
    cat > "${CONFIG_FILE}" << 'BASECONFIG'
{
  "gateway": {
    "mode": "local",
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
    if [ -n "${OPENCLAW_GATEWAY_TOKEN}" ]; then
        jq --arg token "${OPENCLAW_GATEWAY_TOKEN}" \
           '.gateway.auth.token = $token' \
           "${CONFIG_FILE}" > "${temp_config}" && mv "${temp_config}" "${CONFIG_FILE}"
    fi

    # Model configuration (new schema: agents.defaults.model.primary)
    if [ -n "${OPENCLAW_MODEL}" ]; then
        jq --arg model "${OPENCLAW_MODEL}" \
           '.agents.defaults.model.primary = $model' \
           "${CONFIG_FILE}" > "${temp_config}" && mv "${temp_config}" "${CONFIG_FILE}"
    fi
    
    # API Keys are read directly from environment variables:
    # - ANTHROPIC_API_KEY
    # - OPENAI_API_KEY  
    # - OPENROUTER_API_KEY
    # No need to add them to the config file
    
    # Telegram bot token - automatically enable if configured
    if [ -n "${TELEGRAM_BOT_TOKEN}" ]; then
        jq --arg token "${TELEGRAM_BOT_TOKEN}" \
           '.channels.telegram.enabled = true | .channels.telegram.botToken = $token' \
           "${CONFIG_FILE}" > "${temp_config}" && mv "${temp_config}" "${CONFIG_FILE}"
        echo "✅ Telegram channel enabled with provided token"
    fi

    # Discord bot token - automatically enable if configured
    if [ -n "${DISCORD_BOT_TOKEN}" ]; then
        jq --arg token "${DISCORD_BOT_TOKEN}" \
           '.channels.discord.enabled = true | .channels.discord.token = $token' \
           "${CONFIG_FILE}" > "${temp_config}" && mv "${temp_config}" "${CONFIG_FILE}"
        echo "✅ Discord channel enabled with provided token"
    fi

    # Slack tokens - automatically enable if configured
    if [ -n "${SLACK_BOT_TOKEN}" ] && [ -n "${SLACK_APP_TOKEN}" ]; then
        jq --arg bot "${SLACK_BOT_TOKEN}" --arg app "${SLACK_APP_TOKEN}" \
           '.channels.slack.enabled = true | .channels.slack.botToken = $bot | .channels.slack.appToken = $app' \
           "${CONFIG_FILE}" > "${temp_config}" && mv "${temp_config}" "${CONFIG_FILE}"
        echo "✅ Slack channel enabled with provided tokens"
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
# OpenClaw Agent Workspace

This workspace is configured for automated AI assistance via OpenClaw.

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
# OpenClaw Soul Configuration

You are OpenClaw, a helpful personal AI assistant running in a self-hosted environment.

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
    if [ -z "${OPENCLAW_GATEWAY_TOKEN}" ]; then
        # Generate a new token if not provided
        export OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | xxd -p)
        echo "🔑 Generated new gateway token: ${OPENCLAW_GATEWAY_TOKEN:0:8}..."
        echo "   Store this token securely for future access!"
    else
        echo "🔑 Using provided gateway token: ${OPENCLAW_GATEWAY_TOKEN:0:8}..."
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
    echo "🌐 OpenClaw Gateway is starting..."
    echo "════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "📡 Gateway URL:     http://${hostname}:18789"
    echo "🔐 Dashboard URL:   http://${hostname}:18789/?token=${OPENCLAW_GATEWAY_TOKEN}"
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
# Clean up stale lock files from previous runs
# ============================================================================
cleanup_stale_locks() {
    echo "🧹 Cleaning up stale lock files..."

    local lock_count=0

    # Find and remove all .lock files in agent sessions directories
    if [ -d "${CONFIG_DIR}/agents" ]; then
        while IFS= read -r -d '' lockfile; do
            rm -f "$lockfile"
            ((lock_count++))
        done < <(find "${CONFIG_DIR}/agents" -name "*.lock" -print0 2>/dev/null)

        if [ $lock_count -gt 0 ]; then
            echo "✅ Removed ${lock_count} stale lock file(s)"
        else
            echo "✅ No stale lock files found"
        fi
    fi
}

# ============================================================================
# Main execution
# ============================================================================
main() {
    # Initialize token
    init_gateway_token

    # Clean up stale locks from previous container crashes
    cleanup_stale_locks

    # Generate or update configuration
    generate_config

    # Setup Claude automation
    setup_claude_automation

    # Show connection info
    show_connection_info

    # Start the gateway
    echo "🚀 Starting OpenClaw Gateway..."

    # Initialize D-Bus session if not already running
    if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
        if command -v dbus-launch &> /dev/null; then
            echo "🔧 Initializing D-Bus session..."
            eval $(dbus-launch --sh-syntax)
            export DBUS_SESSION_BUS_ADDRESS
            export DBUS_SESSION_BUS_PID
        else
            echo "⚠️  dbus-launch not available, setting minimal D-Bus environment..."
            export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
        fi
    fi

    exec openclaw gateway start \
        --port "${GATEWAY_PORT:-18789}" \
        --token "${OPENCLAW_GATEWAY_TOKEN}" \
        ${GATEWAY_VERBOSE:+--verbose}
}

# Run main function
main "$@"
