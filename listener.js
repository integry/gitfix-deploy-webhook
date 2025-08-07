// ~/mcp-webhook-listener/listener.js
const express = require('express');
const bodyParser = require('body-parser');
const crypto = require('crypto');
const { exec } = require('shelljs');

const app = express();
const PORT = 8081; // Run the listener on a separate port
const GITHUB_SECRET = '4e8Z9A7NHTK1q6771eUnSIi5ag7cq6YqT7aXcNWf9gx1u4IQdS'; // **IMPORTANT**: Set a strong secret
const REPO_OWNER = 'integry'; // Repository owner
const REPO_NAME = 'mcptest'; // Repository name

app.use(bodyParser.json());

function ensureSubdomainLength(branchName) {
    // Sanitize the branch name first
    const sanitized = branchName.replace(/[^a-zA-Z0-9-]/g, '-');
    
    // The full subdomain will be "dev-{sanitized}"
    const prefix = 'dev-';
    const maxLength = 63;
    const maxBranchLength = maxLength - prefix.length;
    
    if (sanitized.length <= maxBranchLength) {
        return sanitized;
    }
    
    // Truncate to fit within the limit, preserving some uniqueness with a hash suffix
    const crypto = require('crypto');
    const hash = crypto.createHash('sha256').update(sanitized).digest('hex').substring(0, 6);
    const truncateLength = maxBranchLength - hash.length - 1; // -1 for the hyphen
    
    return sanitized.substring(0, truncateLength) + '-' + hash;
}

function verifySignature(req, res, next) {
    const signature = req.headers['x-hub-signature-256'];
    if (!signature) {
        return res.status(401).send('Signature required');
    }
    const hmac = crypto.createHmac('sha256', GITHUB_SECRET);
    const digest = 'sha256=' + hmac.update(JSON.stringify(req.body)).digest('hex');

    if (!crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(digest))) {
        return res.status(401).send('Invalid signature');
    }
    next();
}

app.post('/webhook', verifySignature, (req, res) => {
    const event = req.headers['x-github-event'];
    
    if (event === 'push') {
        const ref = req.body.ref; // e.g., "refs/heads/feature-branch"
        if (!ref.startsWith('refs/heads/')) {
            console.log('Push was not to a branch, ignoring.');
            return res.status(200).send('Push was not to a branch, ignoring.');
        }

        const branchName = ref.replace('refs/heads/', '');
        const sanitizedBranchName = ensureSubdomainLength(branchName); // Sanitize and ensure length limit
        
        console.log(`Received push event for branch: ${branchName}`);
        
        // Check if this branch has an associated PR
        // Use gh CLI to check for open PRs from this branch
        const checkPRCommand = `gh pr list --repo ${REPO_OWNER}/${REPO_NAME} --head ${branchName} --state open --json number --jq '.[0].number // empty' 2>/dev/null || echo ""`;
        const ghResult = exec(checkPRCommand, { silent: true });
        
        if (ghResult.code === 0) {
            const prNumber = ghResult.stdout.trim();
            if (prNumber) {
                console.log(`Branch ${branchName} has an open PR #${prNumber}, skipping push deployment (will be handled by pull_request event)`);
                return res.status(200).send('Push event for PR branch ignored - handled by pull_request event.');
            }
        } else {
            console.log('Warning: Unable to check for PRs - gh CLI may not be authenticated. Proceeding with deployment.');
        }
        
        // Special handling for master branch
        if (branchName === 'master') {
            console.log('Deploying to main production site...');
            // Add a delay for master pushes to avoid race conditions with PR cleanup
            console.log('Adding 5-second delay to avoid race condition with PR branch cleanup...');
            setTimeout(() => {
                exec(`./deploy-main-site.sh ${req.body.deleted}`, { async: true });
            }, 5000);
        } else {
            // For other branches without PRs, use regular deployment
            console.log(`Deploying non-PR branch: ${branchName}`);
            exec(`./deploy-branch.sh "${branchName}" ${sanitizedBranchName} ${req.body.deleted}`, { async: true });
        }

        res.status(202).send('Accepted: Build process started.');
    } else if (event === 'pull_request') {
        // Handle pull request events (opened, synchronize, reopened)
        const action = req.body.action;
        const pr = req.body.pull_request;
        
        // Process PR events that indicate branch updates
        if (['opened', 'synchronize', 'reopened'].includes(action)) {
            const branchName = pr.head.ref; // The source branch of the PR
            const sanitizedBranchName = ensureSubdomainLength(branchName);
            const prNumber = pr.number;
            
            console.log(`Received pull_request event (${action}) for branch: ${branchName} (PR #${prNumber})`);
            
            // Deploy the PR branch with PR commenting using gh CLI
            const deployCmd = `./deploy-with-gh-comment.sh "${branchName}" ${sanitizedBranchName} false ${prNumber} ${REPO_OWNER} ${REPO_NAME}`;
            
            exec(deployCmd, { async: true });
            
            res.status(202).send('Accepted: Build process started for PR branch.');
        } else if (action === 'closed') {
            // If PR is closed, we might want to clean up the deployment
            const branchName = pr.head.ref;
            const sanitizedBranchName = ensureSubdomainLength(branchName);
            const prNumber = pr.number;
            
            console.log(`Received pull_request closed event for branch: ${branchName} (PR #${prNumber})`);
            
            // Mark branch as deleted to trigger cleanup
            const deployCmd = `./deploy-with-gh-comment.sh "${branchName}" ${sanitizedBranchName} true ${prNumber} ${REPO_OWNER} ${REPO_NAME}`;
                
            exec(deployCmd, { async: true });
            
            res.status(202).send('Accepted: Cleanup process started for closed PR.');
        } else {
            // Other PR actions we don't need to handle
            console.log(`Received pull_request event with action: ${action}, ignoring.`);
            res.status(200).send(`Pull request action '${action}' not handled.`);
        }
    } else {
        res.status(200).send('Event not handled.');
    }
});

app.listen(PORT, () => console.log(`Webhook listener running on http://localhost:${PORT}`));
