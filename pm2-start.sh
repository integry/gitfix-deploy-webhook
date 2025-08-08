#!/bin/bash

# PM2 Start Script for MCP Webhook Listener

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

echo -e "${GREEN}Starting ${APP_NAME}...${NC}"

# Check if .env file exists
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo -e "${YELLOW}Warning: .env file not found!${NC}"
    echo "Creating .env from .env.example..."
    if [ -f "$SCRIPT_DIR/.env.example" ]; then
        cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
        echo -e "${YELLOW}Please edit .env file with your configuration before starting.${NC}"
        exit 1
    else
        echo -e "${RED}Error: .env.example not found!${NC}"
        exit 1
    fi
fi

# Install dependencies if node_modules doesn't exist
if [ ! -d "$SCRIPT_DIR/node_modules" ]; then
    echo "Installing dependencies..."
    cd "$SCRIPT_DIR"
    npm install
fi

# Check if already running
if pm2 list | grep -q "$APP_NAME"; then
    echo -e "${YELLOW}$APP_NAME is already running!${NC}"
    echo "Use './pm2-restart.sh' to restart or './pm2-stop.sh' to stop first."
    exit 1
fi

# Start with PM2
cd "$SCRIPT_DIR"
pm2 start ecosystem.config.js

# Save PM2 process list
pm2 save

# Show status
echo -e "${GREEN}$APP_NAME started successfully!${NC}"
echo ""
echo "Useful commands:"
echo "  ./pm2-status.sh  - View status and recent logs"
echo "  ./pm2-restart.sh - Restart the service"
echo "  ./pm2-stop.sh    - Stop the service"
echo "  pm2 logs $APP_NAME - View real-time logs"
echo ""
echo -e "${GREEN}Webhook listener is running on port ${WEBHOOK_PORT}${NC}"