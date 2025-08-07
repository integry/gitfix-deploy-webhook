#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status.

# Accept both original and sanitized branch names
GIT_BRANCH_NAME=$1
SANITIZED_BRANCH_NAME=$2
IS_DELETED=$3

REPO_DIR="/var/www/mcptest/repo"
BRANCHES_BASE_DIR="/var/www/mcptest/branches"
BRANCH_DIR="$BRANCHES_BASE_DIR/$SANITIZED_BRANCH_NAME"

echo "--- Starting deployment for branch: $GIT_BRANCH_NAME ---"
echo "--- Using directory name: $SANITIZED_BRANCH_NAME ---"

# --- Handle Branch Deletion ---
if [ "$IS_DELETED" = "true" ]; then
    echo "Branch was deleted. Cleaning up..."
    if [ -d "$BRANCH_DIR" ]; then
        rm -rf "$BRANCH_DIR"
        echo "Removed directory: $BRANCH_DIR"
    fi
    echo "--- Cleanup for $GIT_BRANCH_NAME complete. ---"
    exit 0
fi

# --- Handle Branch Creation/Update ---

# Ensure base directories exist
mkdir -p "$BRANCHES_BASE_DIR"
sudo chown -R $USER:$USER /var/www/mcptest

# Clone the main repo if it doesn't exist
if [ ! -d "$REPO_DIR" ]; then
    echo "Cloning main repository..."
    git clone git@github.com:integry/mcptest.git "$REPO_DIR"
fi

# Add delay to ensure GitHub has processed the push
echo "Waiting 3 seconds for GitHub to process the push..."
sleep 3

# Fetch latest changes in the main repo
cd "$REPO_DIR"
git fetch origin --prune
git fetch origin "+refs/heads/*:refs/remotes/origin/*"

# Create a clean directory for the branch build
rm -rf "$BRANCH_DIR" 2>/dev/null || true
mkdir -p "$BRANCH_DIR"

# Checkout the specific branch into our build directory
echo "Checking out branch $GIT_BRANCH_NAME..."
# Try to checkout existing branch or create new one tracking remote
git checkout -B "$GIT_BRANCH_NAME" "origin/$GIT_BRANCH_NAME" || {
    echo "Failed to checkout branch $GIT_BRANCH_NAME"
    exit 1
}
# Copy files to the build directory (avoids issues with git worktree in scripts)
cp -r . "$BRANCH_DIR/"

# Copy .env file to enable Firebase Auth
if [ -f "/root/mcp-webhook-listener/.env" ]; then
    echo "Copying .env file for Firebase Auth configuration..."
    cp "/root/mcp-webhook-listener/.env" "$BRANCH_DIR/"
fi

# Build the application
cd "$BRANCH_DIR"

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

echo "--- Deployment for $GIT_BRANCH_NAME successful! ---"
echo "Live at: https://dev-$SANITIZED_BRANCH_NAME.mcptest.io"
