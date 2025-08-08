#!/bin/bash

# PM2 Status Script for MCP Webhook Listener

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables
source "$SCRIPT_DIR/load-env.sh"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== ${APP_NAME} Status ===${NC}"
echo ""

# Show PM2 process status
pm2 show "$APP_NAME" 2>/dev/null || {
    echo -e "${RED}$APP_NAME is not running!${NC}"
    echo "Start it with: ./pm2-start.sh"
    exit 1
}

echo ""
echo -e "${BLUE}=== Recent Logs (last 20 lines) ===${NC}"
echo ""

# Show recent logs
pm2 logs "$APP_NAME" --lines 20 --nostream

echo ""
echo -e "${BLUE}=== Quick Info ===${NC}"
echo -e "Webhook URL: ${GREEN}http://localhost:${WEBHOOK_PORT}/webhook${NC}"
echo -e "Repository: ${GREEN}${REPO_OWNER}/${REPO_NAME}${NC}"
echo -e "Main branch: ${GREEN}${DEPLOY_MAIN_BRANCH}${NC}"
echo -e "Deploy domain: ${GREEN}${DEPLOY_BASE_DOMAIN}${NC}"
echo ""
echo "Commands:"
echo "  pm2 logs $APP_NAME         - View real-time logs"
echo "  pm2 monit                  - Monitor CPU/Memory usage"
echo "  ./pm2-restart.sh           - Restart the service"
echo "  ./pm2-stop.sh              - Stop the service"