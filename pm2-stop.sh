#!/bin/bash

# PM2 Stop Script for MCP Webhook Listener

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables
source "$SCRIPT_DIR/load-env.sh"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Stopping ${APP_NAME}...${NC}"

# Check if running
if ! pm2 list | grep -q "$APP_NAME"; then
    echo -e "${YELLOW}$APP_NAME is not running.${NC}"
    exit 0
fi

# Stop the application
pm2 stop "$APP_NAME"

# Delete from PM2 process list
pm2 delete "$APP_NAME"

# Save PM2 process list
pm2 save

echo -e "${GREEN}$APP_NAME stopped successfully!${NC}"
echo ""
echo "To start again, run: ./pm2-start.sh"