#!/bin/bash

# Example gitfix-install.sh for a Node.js project
# This file should be placed in the root of your project repository
# It will be executed automatically during deployment after npm install and build

set -e

# Use the logging functions from the environment
log() {
    echo "[CUSTOM] $1"
}

error() {
    echo "[CUSTOM ERROR] $1" >&2
}

# Environment variables provided by the deployment system:
# - PROJECT_DIR: The directory containing your project source code
# - BUILD_DIR: The directory where the built application should be placed
# - DEPLOY_ENV: The deployment environment (development/production)

log "Running custom installation for MyApp..."
log "Project directory: $PROJECT_DIR"
log "Build directory: $BUILD_DIR"
log "Deploy environment: $DEPLOY_ENV"

# Example 1: Copy additional configuration files
if [ -f "$PROJECT_DIR/config.$DEPLOY_ENV.json" ]; then
    log "Copying environment-specific configuration..."
    cp "$PROJECT_DIR/config.$DEPLOY_ENV.json" "$BUILD_DIR/config.json"
fi

# Example 2: Create necessary directories
log "Creating required directories..."
mkdir -p "$BUILD_DIR/uploads"
mkdir -p "$BUILD_DIR/logs"
mkdir -p "$BUILD_DIR/cache"

# Example 3: Set up environment-specific files
if [ "$DEPLOY_ENV" = "production" ]; then
    log "Setting up production environment..."
    # Remove development files
    rm -f "$BUILD_DIR/dist/dev-tools.js"
    # Enable production optimizations
    echo '{"production": true}' > "$BUILD_DIR/dist/env.json"
else
    log "Setting up development environment..."
    # Enable development features
    echo '{"production": false, "debug": true}' > "$BUILD_DIR/dist/env.json"
fi

# Example 4: Database setup (if needed)
if [ -f "$PROJECT_DIR/database/schema.sql" ]; then
    log "Database schema found, but skipping automatic setup for safety"
    log "Please run database migrations manually if needed"
fi

# Example 5: Generate static assets or configurations
if [ -f "$PROJECT_DIR/scripts/generate-assets.js" ]; then
    log "Generating static assets..."
    node "$PROJECT_DIR/scripts/generate-assets.js"
fi

# Example 6: Set proper file permissions
log "Setting file permissions..."
find "$BUILD_DIR/uploads" -type d -exec chmod 755 {} \;
find "$BUILD_DIR/logs" -type d -exec chmod 755 {} \;
find "$BUILD_DIR/cache" -type d -exec chmod 755 {} \;

# Example 7: Create symbolic links if needed
if [ -d "$PROJECT_DIR/shared/assets" ]; then
    log "Creating symbolic link for shared assets..."
    ln -sf "$PROJECT_DIR/shared/assets" "$BUILD_DIR/dist/shared-assets"
fi

# Example 8: Run post-build optimizations
if [ -f "$PROJECT_DIR/scripts/optimize.sh" ]; then
    log "Running post-build optimizations..."
    bash "$PROJECT_DIR/scripts/optimize.sh" "$BUILD_DIR"
fi

# Example 9: Validate the deployment
log "Running deployment validation..."
if [ ! -f "$BUILD_DIR/dist/index.html" ]; then
    error "Build validation failed: index.html not found"
    exit 1
fi

if [ ! -d "$BUILD_DIR/dist/assets" ]; then
    error "Build validation failed: assets directory not found"
    exit 1
fi

log "Custom installation completed successfully!"
log "Application is ready for deployment"

# Exit successfully
exit 0