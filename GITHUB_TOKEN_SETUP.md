# GitHub CLI Setup for PR Comments

The webhook listener now uses GitHub CLI (`gh`) for posting PR comments, which is much simpler than managing tokens manually.

## Setup (Already Completed):

GitHub CLI is already authenticated on this system:
```bash
gh auth status
# ✓ Logged in to github.com account integry
```

## How It Works:

When a pull request webhook is received, the system will:
1. Deploy the branch automatically
2. Capture build logs
3. Post a comment to the PR with:
   - ✅ **Success**: Link to test site + last 50 lines of build logs
   - ❌ **Failure**: Error details + last 200 lines of build logs
   - 🧹 **Cleanup**: Confirmation when PR is closed

## Example Comment Format:

### Successful Deployment:
```
## 🚀 Deployment Successful!

**Branch**: `ai-fix/18-feat-add-automatic-sse-ht-20250714-1909-opus-scp`
**Test Site**: https://dev-ai-fix-18-feat-add-automatic-sse-ht-20250714-1909-opus-scp.mcptest.io

### Build Log (last 50 lines):
```
[build output]
```

---
*Deployed at [timestamp]*
```

### Failed Deployment:
```
## ❌ Deployment Failed

**Branch**: `branch-name`
**Exit Code**: 1

### Build Log (last 200 lines):
```
[error logs]
```

---
*Failed at [timestamp]*
```

## Verification:

Check that comments are posted after webhook events:
```bash
pm2 logs mcp-webhook-listener
```

## Fallback Behavior:

If `gh` CLI becomes unauthenticated, the webhook will:
- Still deploy branches normally
- Skip PR commenting with a log message
- Continue functioning for all other operations

No additional setup required - the system is ready to use!