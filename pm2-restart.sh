#!/bin/bash

# PM2 Restart Script for MCP Webhook Listener

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

echo -e "${YELLOW}Restarting ${APP_NAME}...${NC}"

# Check if .env file exists
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo -e "${RED}Error: .env file not found!${NC}"
    echo "Please create .env file from .env.example before starting."
    exit 1
fi

# Update dependencies if package.json has changed
echo "Checking for dependency updates..."
cd "$SCRIPT_DIR"
if [ -f "package-lock.json" ]; then
    npm ci --silent
else
    npm install --silent
fi

# Check if running
if pm2 list | grep -q "$APP_NAME"; then
    # If running, do a graceful reload
    echo "Performing graceful reload..."
    pm2 reload ecosystem.config.js --update-env
else
    # If not running, start it
    echo "$APP_NAME is not running. Starting..."
    pm2 start ecosystem.config.js
fi

# Save PM2 process list
pm2 save

echo -e "${GREEN}$APP_NAME restarted successfully!${NC}"
echo ""
echo "View logs with: pm2 logs $APP_NAME"
echo "View status with: ./pm2-status.sh"