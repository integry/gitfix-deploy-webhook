#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status.

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables
source "$SCRIPT_DIR/load-env.sh"

IS_DELETED=$1
REPO_DIR="$REPO_CLONE_DIR"
MAIN_SITE_DIR="$MAIN_SITE_DIR"

echo "--- Starting deployment for main site ($DEPLOY_MAIN_BRANCH branch) ---"

# If main branch was somehow deleted (shouldn't happen), exit
if [ "$IS_DELETED" = "true" ]; then
    echo "Warning: Main branch deletion event received. Ignoring."
    exit 0
fi

# Ensure base directories exist
mkdir -p "$(dirname "$MAIN_SITE_DIR")"
sudo chown -R $USER:$USER "$DEPLOY_BASE_DIR"

# Clone the main repo if it doesn't exist
if [ ! -d "$REPO_DIR" ]; then
    echo "Cloning main repository..."
    git clone "$DEPLOY_REPO_URL" "$REPO_DIR"
fi

# Add delay to ensure GitHub has processed the push
echo "Waiting 3 seconds for GitHub to process the push..."
sleep 3

# Fetch latest changes
cd "$REPO_DIR"
echo "Fetching latest changes..."
git fetch origin --prune

# Checkout main branch
echo "Checking out $DEPLOY_MAIN_BRANCH branch..."
git checkout "$DEPLOY_MAIN_BRANCH"
git pull origin "$DEPLOY_MAIN_BRANCH"

# Create a clean directory for the main site build
rm -rf "$MAIN_SITE_DIR" 2>/dev/null || true
mkdir -p "$MAIN_SITE_DIR"

# Copy files to the build directory
echo "Copying files to main site directory..."
cp -r . "$MAIN_SITE_DIR/"

# Copy deployment-specific .env file if specified
if [ -n "$BUILD_ENV_FILE" ] && [ -f "$BUILD_ENV_FILE" ]; then
    echo "Copying deployment-specific .env file: $BUILD_ENV_FILE"
    cp "$BUILD_ENV_FILE" "$MAIN_SITE_DIR/.env"
elif [ -f "$SCRIPT_DIR/.env.${DEPLOYMENT_NAME}" ]; then
    echo "Copying .env file for deployment: ${DEPLOYMENT_NAME}"
    cp "$SCRIPT_DIR/.env.${DEPLOYMENT_NAME}" "$MAIN_SITE_DIR/.env"
elif [ -f "$SCRIPT_DIR/.env" ]; then
    echo "Copying default .env file..."
    cp "$SCRIPT_DIR/.env" "$MAIN_SITE_DIR/"
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
        
        # Ensure we install all dependencies including devDependencies
        if NODE_ENV=development npm install; then
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

# Run custom gitfix-install.sh if present
if [ -f "$SCRIPT_DIR/run-gitfix-install.sh" ]; then
    echo "Running custom installation script if present..."
    # Check if this is a production branch
    if [[ ",$PRODUCTION_BRANCHES," == *",$DEPLOY_MAIN_BRANCH,"* ]]; then
        DEPLOY_ENV="production"
    else
        DEPLOY_ENV="$DEFAULT_DEPLOY_ENV"
    fi
    "$SCRIPT_DIR/run-gitfix-install.sh" "$MAIN_SITE_DIR" "$MAIN_SITE_DIR" "$DEPLOY_ENV" || {
        echo "WARNING: Custom installation script failed, continuing with deployment"
    }
fi

# Ensure nginx can read the files
sudo chown -R www-data:www-data "$MAIN_SITE_DIR/dist"

echo "--- Main site deployment successful! ---"
echo "Live at: https://${DEPLOY_BASE_DOMAIN} and https://www.${DEPLOY_BASE_DOMAIN}"