#!/bin/bash

# Security wrapper script to execute gitfix-install.sh with limited permissions
# This script is called by the deployment scripts to run project-specific installation

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Check required parameters
if [ $# -lt 2 ]; then
    error "Usage: $0 <project_directory> <build_directory>"
    exit 1
fi

PROJECT_DIR="$1"
BUILD_DIR="$2"
DEPLOY_ENV="${3:-development}"

# Validate directories
if [ ! -d "$PROJECT_DIR" ]; then
    error "Project directory does not exist: $PROJECT_DIR"
    exit 1
fi

if [ ! -d "$BUILD_DIR" ]; then
    error "Build directory does not exist: $BUILD_DIR"
    exit 1
fi

# Check if gitfix-install.sh exists in the project
INSTALL_SCRIPT="$PROJECT_DIR/gitfix-install.sh"
if [ ! -f "$INSTALL_SCRIPT" ]; then
    log "No gitfix-install.sh found in project directory, skipping custom installation"
    exit 0
fi

# Verify the script is executable
if [ ! -x "$INSTALL_SCRIPT" ]; then
    log "Making gitfix-install.sh executable..."
    chmod +x "$INSTALL_SCRIPT"
fi

# Security checks
log "Running security checks on gitfix-install.sh..."

# Check for potentially dangerous commands
DANGEROUS_PATTERNS=(
    "rm -rf /"
    "rm -rf /*"
    "chmod 777 /"
    "chown -R"
    "systemctl"
    "service"
    "sudo"
    "su -"
    "passwd"
    "useradd"
    "groupadd"
    "visudo"
    "crontab -r"
    "iptables"
    "firewall-cmd"
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
    if grep -q "$pattern" "$INSTALL_SCRIPT"; then
        warning "Potentially dangerous command detected in gitfix-install.sh: $pattern"
        warning "Manual review recommended before proceeding"
    fi
done

# Set up environment for the install script
export PROJECT_DIR
export BUILD_DIR
export DEPLOY_ENV

# Create a temporary directory for the script to use
TEMP_DIR=$(mktemp -d)
export TEMP_DIR
trap "rm -rf $TEMP_DIR" EXIT

log "Executing gitfix-install.sh..."
log "Project directory: $PROJECT_DIR"
log "Build directory: $BUILD_DIR"
log "Deploy environment: $DEPLOY_ENV"

# Change to project directory and run the install script
cd "$PROJECT_DIR"

# Set resource limits for the script execution
# Limit CPU time to 10 minutes
ulimit -t 600
# Limit memory to 2GB
ulimit -v 2097152
# Limit number of processes
ulimit -u 100
# Limit file size to 100MB
ulimit -f 102400

# Execute the install script with timeout
# 15 minute timeout for the entire script
if timeout 900 bash "$INSTALL_SCRIPT" 2>&1; then
    log "Custom installation completed successfully"
    exit 0
else
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 124 ]; then
        error "Custom installation timed out after 15 minutes"
    else
        error "Custom installation failed with exit code: $EXIT_CODE"
    fi
    exit $EXIT_CODE
fi