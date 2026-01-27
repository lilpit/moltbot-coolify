#!/bin/bash
# ============================================================================
# MoltBot Health Check Script for Coolify
# ============================================================================

set -e

GATEWAY_PORT="${GATEWAY_PORT:-18789}"
HEALTH_URL="http://localhost:${GATEWAY_PORT}/health"

# Try to get health status
response=$(curl -sf "${HEALTH_URL}" 2>/dev/null || echo "failed")

if [ "$response" = "failed" ]; then
    echo "❌ Gateway health check failed"
    exit 1
fi

# Check if response contains "ok" or similar success indicator
if echo "$response" | grep -qi "ok\|healthy\|running"; then
    echo "✅ Gateway is healthy"
    exit 0
fi

# Alternative: check if the port is listening
if nc -z localhost "${GATEWAY_PORT}" 2>/dev/null; then
    echo "✅ Gateway port is responding"
    exit 0
fi

echo "❌ Gateway health check failed"
exit 1
