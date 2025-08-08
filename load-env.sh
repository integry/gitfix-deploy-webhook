#!/bin/bash

# Load environment variables from .env file
# This script should be sourced by other scripts that need env vars

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load .env file if it exists
if [ -f "$SCRIPT_DIR/.env" ]; then
    # Export all variables from .env file
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
else
    echo "Warning: .env file not found at $SCRIPT_DIR/.env"
    echo "Using default values or environment variables"
fi

# Set defaults for critical variables if not already set
export DEPLOY_BASE_DOMAIN="${DEPLOY_BASE_DOMAIN}"
export DEPLOY_BASE_DIR="${DEPLOY_BASE_DIR}"
export DEPLOY_REPO_URL="${DEPLOY_REPO_URL}"
export DEPLOY_MAIN_BRANCH="${DEPLOY_MAIN_BRANCH:-master}"
export DEPLOY_BRANCH_SUBDOMAIN_PREFIX="${DEPLOY_BRANCH_SUBDOMAIN_PREFIX:-dev-}"
export WEBHOOK_PORT="${WEBHOOK_PORT:-8081}"
export REPO_OWNER="${REPO_OWNER}"
export REPO_NAME="${REPO_NAME}"
export APP_NAME="${APP_NAME:-gitfix-deploy-webhook}"
# Don't set NODE_ENV here - let deployment scripts handle it
# export NODE_ENV="${NODE_ENV:-production}"
export DEFAULT_DEPLOY_ENV="${DEFAULT_DEPLOY_ENV:-development}"
export PRODUCTION_BRANCHES="${PRODUCTION_BRANCHES:-master,main}"

# Derived variables
export REPO_CLONE_DIR="${REPO_CLONE_DIR:-${DEPLOY_BASE_DIR}/repo}"
export MAIN_SITE_DIR="${MAIN_SITE_DIR:-${DEPLOY_BASE_DIR}/main}"
export BRANCHES_BASE_DIR="${BRANCHES_BASE_DIR:-${DEPLOY_BASE_DIR}/branches}"