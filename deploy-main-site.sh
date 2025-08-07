#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status.

IS_DELETED=$1
REPO_DIR="/var/www/mcptest/repo"
MAIN_SITE_DIR="/var/www/mcptest/main"

echo "--- Starting deployment for main site (master branch) ---"

# If master branch was somehow deleted (shouldn't happen), exit
if [ "$IS_DELETED" = "true" ]; then
    echo "Warning: Master branch deletion event received. Ignoring."
    exit 0
fi

# Ensure base directories exist
mkdir -p "$(dirname "$MAIN_SITE_DIR")"
sudo chown -R $USER:$USER /var/www/mcptest

# Clone the main repo if it doesn't exist
if [ ! -d "$REPO_DIR" ]; then
    echo "Cloning main repository..."
    git clone git@github.com:integry/mcptest.git "$REPO_DIR"
fi

# Add delay to ensure GitHub has processed the push
echo "Waiting 3 seconds for GitHub to process the push..."
sleep 3

# Fetch latest changes
cd "$REPO_DIR"
echo "Fetching latest changes..."
git fetch origin --prune

# Checkout master branch
echo "Checking out master branch..."
git checkout master
git pull origin master

# Create a clean directory for the main site build
rm -rf "$MAIN_SITE_DIR" 2>/dev/null || true
mkdir -p "$MAIN_SITE_DIR"

# Copy files to the build directory
echo "Copying files to main site directory..."
cp -r . "$MAIN_SITE_DIR/"

# Copy .env file to enable Firebase Auth
if [ -f "/root/mcp-webhook-listener/.env" ]; then
    echo "Copying .env file for Firebase Auth configuration..."
    cp "/root/mcp-webhook-listener/.env" "$MAIN_SITE_DIR/"
fi

# Build the application
cd "$MAIN_SITE_DIR"

# Function to retry npm install
retry_npm_install() {
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "Installing dependencies (attempt $attempt of $max_attempts)..."
        
        # Clean install to avoid any issues
        rm -rf node_modules package-lock.json .npm
        
        # Add a small delay to let filesystem settle
        sleep 2
        
        if npm install; then
            echo "Dependencies installed successfully"
            return 0
        else
            echo "npm install failed (attempt $attempt)"
            
            if [ $attempt -lt $max_attempts ]; then
                echo "Waiting 30 seconds before retry..."
                sleep 30
                
                # More aggressive cleanup for retry
                rm -rf node_modules package-lock.json .npm
                # Clear npm cache
                npm cache clean --force 2>/dev/null || true
            fi
            
            attempt=$((attempt + 1))
        fi
    done
    
    echo "Failed to install dependencies after $max_attempts attempts"
    return 1
}

# Try to install dependencies with retry
if ! retry_npm_install; then
    echo "ERROR: Unable to install dependencies"
    exit 1
fi

echo "Building the application..."
npm run build

# Ensure nginx can read the files
sudo chown -R www-data:www-data "$MAIN_SITE_DIR/dist"

echo "--- Main site deployment successful! ---"
echo "Live at: https://mcptest.io and https://www.mcptest.io"