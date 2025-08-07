#!/bin/bash

# This script wraps the deployment and posts results to GitHub PR

GIT_BRANCH_NAME=$1
SANITIZED_BRANCH_NAME=$2
IS_DELETED=$3
PR_NUMBER=$4
REPO_OWNER=$5
REPO_NAME=$6
GITHUB_TOKEN=$7

LOG_FILE="/tmp/deploy-${SANITIZED_BRANCH_NAME}-$(date +%s).log"

# Function to post comment to PR
post_pr_comment() {
    local comment_body=$1
    
    if [ -z "$PR_NUMBER" ] || [ -z "$GITHUB_TOKEN" ]; then
        echo "Skipping PR comment - missing PR number or GitHub token"
        return
    fi
    
    # Escape special characters in JSON
    escaped_body=$(echo "$comment_body" | jq -R -s '.')
    
    curl -s -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Content-Type: application/json" \
        "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/issues/$PR_NUMBER/comments" \
        -d "{\"body\": $escaped_body}" > /dev/null
}

# Handle deletion differently
if [ "$IS_DELETED" = "true" ]; then
    # Run cleanup
    ./deploy-branch.sh "$GIT_BRANCH_NAME" "$SANITIZED_BRANCH_NAME" "$IS_DELETED" 2>&1 | tee "$LOG_FILE"
    DEPLOY_EXIT_CODE=${PIPESTATUS[0]}
    
    if [ $DEPLOY_EXIT_CODE -eq 0 ]; then
        COMMENT_BODY="## 🧹 Deployment Cleaned Up

**Branch**: \`$GIT_BRANCH_NAME\`

The test deployment has been removed.

---
*Cleaned up at $(date)*"
    else
        COMMENT_BODY="## ❌ Cleanup Failed

**Branch**: \`$GIT_BRANCH_NAME\`

Failed to clean up the deployment. Please check the server logs.

---
*Failed at $(date)*"
    fi
    
    post_pr_comment "$COMMENT_BODY"
    exit $DEPLOY_EXIT_CODE
fi

# Run the deployment and capture output
echo "Starting deployment with logging to: $LOG_FILE"
./deploy-branch.sh "$GIT_BRANCH_NAME" "$SANITIZED_BRANCH_NAME" "$IS_DELETED" 2>&1 | tee "$LOG_FILE"
DEPLOY_EXIT_CODE=${PIPESTATUS[0]}

# Prepare comment based on deployment result
if [ $DEPLOY_EXIT_CODE -eq 0 ]; then
    # Success - get last 50 lines
    BUILD_LOG_TAIL=$(tail -n 50 "$LOG_FILE")
    
    COMMENT_BODY="## 🚀 Deployment Successful!

**Branch**: \`$GIT_BRANCH_NAME\`
**Test Site**: https://dev-$SANITIZED_BRANCH_NAME.mcptest.io

### Build Log (last 50 lines):
\`\`\`
$BUILD_LOG_TAIL
\`\`\`

---
*Deployed at $(date)*"
else
    # Failure - get last 200 lines
    BUILD_LOG_TAIL=$(tail -n 200 "$LOG_FILE")
    
    COMMENT_BODY="## ❌ Deployment Failed

**Branch**: \`$GIT_BRANCH_NAME\`
**Exit Code**: $DEPLOY_EXIT_CODE

### Build Log (last 200 lines):
\`\`\`
$BUILD_LOG_TAIL
\`\`\`

---
*Failed at $(date)*"
fi

# Post comment to PR
post_pr_comment "$COMMENT_BODY"

# Clean up old log files (keep last 10)
ls -t /tmp/deploy-${SANITIZED_BRANCH_NAME}-*.log 2>/dev/null | tail -n +11 | xargs -r rm

# Exit with the same code as the deployment
exit $DEPLOY_EXIT_CODE