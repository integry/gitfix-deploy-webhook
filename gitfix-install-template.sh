#!/bin/bash

# Generic GitFix Installation Script Template
# This script is executed after the source code is checked out
# It should be customized for each project's specific installation needs

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to log messages with timestamp
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Verify we're in the correct directory
if [ ! -f "gitfix-install.sh" ]; then
    error "gitfix-install.sh not found in current directory"
    error "This script should be run from the project root where gitfix-install.sh exists"
    exit 1
fi

log "Starting custom installation process..."
log "Current directory: $(pwd)"
log "Running as user: $(whoami)"

# Check for required environment variables
if [ -z "$DEPLOY_ENV" ]; then
    warning "DEPLOY_ENV not set, defaulting to 'development'"
    export DEPLOY_ENV="development"
fi

if [ -z "$BUILD_DIR" ]; then
    error "BUILD_DIR environment variable is required"
    exit 1
fi

# ============================================================================
# CUSTOM INSTALLATION STEPS
# Add your project-specific installation commands below
# ============================================================================

# Example: Node.js project installation
if [ -f "package.json" ]; then
    log "Detected Node.js project (package.json found)"
    
    # Install dependencies
    log "Installing npm dependencies..."
    if ! npm ci --production=false; then
        error "npm install failed"
        exit 1
    fi
    
    # Run build command if it exists
    if npm run | grep -q "build"; then
        log "Running build command..."
        if ! npm run build; then
            error "Build failed"
            exit 1
        fi
    fi
fi

# Example: Python project installation
if [ -f "requirements.txt" ]; then
    log "Detected Python project (requirements.txt found)"
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "venv" ]; then
        log "Creating virtual environment..."
        python3 -m venv venv
    fi
    
    # Activate virtual environment and install dependencies
    log "Installing Python dependencies..."
    source venv/bin/activate
    pip install -r requirements.txt
fi

# Example: Ruby project installation
if [ -f "Gemfile" ]; then
    log "Detected Ruby project (Gemfile found)"
    
    # Install bundler if not present
    if ! command -v bundle &> /dev/null; then
        log "Installing bundler..."
        gem install bundler
    fi
    
    # Install dependencies
    log "Installing Ruby dependencies..."
    bundle install
fi

# Example: Custom build steps
# Uncomment and modify as needed:

# # Copy configuration files
# if [ -f ".env.example" ] && [ ! -f ".env" ]; then
#     log "Creating .env from .env.example..."
#     cp .env.example .env
# fi

# # Run database migrations
# if [ -f "migrate.sh" ]; then
#     log "Running database migrations..."
#     ./migrate.sh
# fi

# # Generate static assets
# if [ -d "assets" ]; then
#     log "Processing static assets..."
#     # Add asset processing commands here
# fi

# # Set up cron jobs
# if [ -f "crontab.txt" ]; then
#     log "Installing cron jobs..."
#     crontab crontab.txt
# fi

# ============================================================================
# POST-INSTALLATION CHECKS
# ============================================================================

# Verify critical files/directories exist
log "Running post-installation checks..."

# Example checks (customize for your project):
# if [ ! -f "$BUILD_DIR/index.html" ] && [ ! -f "$BUILD_DIR/index.php" ]; then
#     warning "No index file found in build directory"
# fi

# Check file permissions
# find "$BUILD_DIR" -type f -exec chmod 644 {} \;
# find "$BUILD_DIR" -type d -exec chmod 755 {} \;

log "Custom installation completed successfully!"
exit 0