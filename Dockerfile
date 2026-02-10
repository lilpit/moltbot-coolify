# OpenClaw (Clawdbot) Dockerfile for Coolify
# Self-hosted personal AI assistant with Claude automation
# https://github.com/openclaw/openclaw

FROM node:22-bookworm

LABEL maintainer="OpenClaw Coolify Configuration"
LABEL description="Personal AI Assistant with Claude automation for Coolify deployment"
LABEL version="1.0.0"

# Build arguments for customization
ARG OPENCLAW_VERSION=latest
ARG EXTRA_APT_PACKAGES=""
ARG INSTALL_CLAUDE_CODE=true

# Environment setup
ENV NODE_ENV=production
ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/home/node
ENV OPENCLAW_HOME=/home/node/.openclaw
ENV WORKSPACE_DIR=/home/node/clawd
ENV PATH="/home/node/.bun/bin:/home/node/.npm-global/bin:${PATH}"

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    git \
    jq \
    gnupg \
    dumb-init \
    procps \
    netcat-openbsd \
    # D-Bus for systemd user services (required by openclaw gateway)
    dbus-user-session \
    systemd \
    # For browser automation (optional)
    chromium \
    chromium-driver \
    # Media processing
    ffmpeg \
    # Additional packages if specified
    ${EXTRA_APT_PACKAGES} \
    && rm -rf /var/lib/apt/lists/*

# Enable corepack for pnpm
RUN corepack enable

# Create non-root user directories
RUN mkdir -p /home/node/.clawdbot \
    /home/node/.openclaw \
    /home/node/clawd \
    /home/node/.npm-global \
    /home/node/.npm \
    /home/node/.claude \
    /home/node/.bun \
    && chown -R node:node /home/node

# Switch to non-root user for installations
USER node

# Install Bun (required for build scripts) as node user
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/home/node/.bun/bin:${PATH}"

# Set working directory
WORKDIR /app

# Configure npm to use node-owned prefix and cache
RUN npm config set prefix '/home/node/.npm-global' \
    && npm config set cache '/home/node/.npm'

# Install OpenClaw (openclaw) globally as node user
RUN npm install -g openclaw@${OPENCLAW_VERSION}

# Install Claude Code CLI for automation (if enabled)
RUN if [ "$INSTALL_CLAUDE_CODE" = "true" ]; then \
        npm install -g @anthropic-ai/claude-code; \
    fi

# Switch back to root to copy files and set permissions
USER root

# Copy configuration and startup scripts
COPY --chown=node:node entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chown=node:node healthcheck.sh /usr/local/bin/healthcheck.sh
COPY --chown=node:node config-template.json /app/config-template.json

# Make scripts executable
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh

# Switch back to non-root user for runtime
USER node

# Expose the gateway port
EXPOSE 18789

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

# Volumes for persistent data
VOLUME ["/home/node/.clawdbot", "/home/node/.openclaw", "/home/node/clawd", "/home/node/.claude"]

# Use dumb-init for proper signal handling
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/usr/local/bin/entrypoint.sh"]
