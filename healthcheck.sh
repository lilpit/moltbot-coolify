#!/bin/bash
# ============================================================================
# OpenClaw Health Check Script for Coolify
# ============================================================================

GATEWAY_PORT="${GATEWAY_PORT:-18789}"
HEALTH_URL="http://localhost:${GATEWAY_PORT}/health"

# Try to get health status with timeout
http_code=$(curl -sf -o /dev/null -w "%{http_code}" --max-time 5 "${HEALTH_URL}" 2>/dev/null || echo "000")

# Check HTTP status code
if [ "$http_code" = "200" ]; then
    echo "✅ Gateway is healthy (HTTP 200)"
    exit 0
fi

# If health endpoint failed, check if port is at least responding
# This handles cases where /health might not exist but gateway is running
if [ "$http_code" = "000" ]; then
    # curl completely failed - check if port is listening
    if nc -z localhost "${GATEWAY_PORT}" 2>/dev/null; then
        echo "⚠️  Gateway port responding but health endpoint unavailable"
        exit 0
    fi
    echo "❌ Gateway not responding on port ${GATEWAY_PORT}"
    exit 1
fi

# HTTP error codes (4xx, 5xx) - service is running but unhealthy
if [ "$http_code" -ge 400 ]; then
    echo "❌ Gateway unhealthy (HTTP ${http_code})"
    exit 1
fi

# Any other 2xx/3xx code is acceptable
echo "✅ Gateway is responding (HTTP ${http_code})"
exit 0
