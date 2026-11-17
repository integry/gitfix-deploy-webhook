// ~/mcp-webhook-listener/listener.js
const express = require('express');
const bodyParser = require('body-parser');
const crypto = require('crypto');
const { exec } = require('shelljs');
const DeploymentConfigManager = require('./deploymentConfig');
require('dotenv').config();

const app = express();
const PORT = process.env.WEBHOOK_PORT || 8081;
const configManager = new DeploymentConfigManager();

// GitHub push payloads for large merges exceed the 100kb default (max is 25MB).
app.use(bodyParser.json({ limit: '25mb' }));

function ensureSubdomainLength(branchName, prefix) {
    // Sanitize the branch name first
    const sanitized = branchName.replace(/[^a-zA-Z0-9-]/g, '-');
    
    // The full subdomain will be "{prefix}{sanitized}"
    const maxLength = 63;
    const maxBranchLength = maxLength - prefix.length;
    
    if (sanitized.length <= maxBranchLength) {
        return sanitized;
    }
    
    // Truncate to fit within the limit, preserving some uniqueness with a hash suffix
    const hash = crypto.createHash('sha256').update(sanitized).digest('hex').substring(0, 6);
    const truncateLength = maxBranchLength - hash.length - 1; // -1 for the hyphen
    
    return sanitized.substring(0, truncateLength) + '-' + hash;
}

function verifySignature(req, res, next) {
    const signature = req.headers['x-hub-signature-256'];
    if (!signature) {
        return res.status(401).send('Signature required');
    }

    // Get repository full name from payload
    const repoFullName = req.body.repository ? req.body.repository.full_name : null;
    if (!repoFullName) {
        return res.status(400).send('Repository information missing');
    }

    // Get config for this repository
    const config = configManager.getConfig(repoFullName);
    if (!config) {
        console.log(`No deployment configuration found for repository: ${repoFullName}`);
        return res.status(404).send('Repository not configured for deployment');
    }

    // Verify signature with repo-specific secret
    const hmac = crypto.createHmac('sha256', config.webhook_secret);
    const digest = 'sha256=' + hmac.update(JSON.stringify(req.body)).digest('hex');

    if (!crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(digest))) {
        return res.status(401).send('Invalid signature');
    }

    // Attach config to request for use in handlers
    req.deploymentConfig = config;
    next();
}

function executeDeployment(scriptPath, args, config) {
    // Build environment variables for the deployment
    const deployEnv = configManager.getDeploymentEnv(config);
    
    // Build the command with environment variables
    const envVars = Object.entries(deployEnv)
        .map(([key, value]) => `${key}="${value}"`)
        .join(' ');
    
    const command = `${envVars} ${scriptPath} ${args.join(' ')}`;
    
    console.log(`Executing deployment for ${config.name}: ${scriptPath}`);
    exec(command, { async: true });
}

app.post('/webhook', verifySignature, (req, res) => {
    const event = req.headers['x-github-event'];
    const config = req.deploymentConfig;
    
    if (event === 'push') {
        const ref = req.body.ref; // e.g., "refs/heads/feature-branch"
        if (!ref.startsWith('refs/heads/')) {
            console.log('Push was not to a branch, ignoring.');
            return res.status(200).send('Push was not to a branch, ignoring.');
        }

        const branchName = ref.replace('refs/heads/', '');
        const sanitizedBranchName = ensureSubdomainLength(branchName, config.deployment.branch_subdomain_prefix);
        
        console.log(`[${config.name}] Received push event for branch: ${branchName}`);
        
        // Check if this branch has an associated PR
        const checkPRCommand = `gh pr list --repo ${config.repo.owner}/${config.repo.name} --head ${branchName} --state open --json number --jq '.[0].number // empty' 2>/dev/null || echo ""`;
        const ghResult = exec(checkPRCommand, { silent: true });
        
        if (ghResult.code === 0) {
            const prNumber = ghResult.stdout.trim();
            if (prNumber) {
                console.log(`[${config.name}] Branch ${branchName} has an open PR #${prNumber}, skipping push deployment`);
                return res.status(200).send('Push event for PR branch ignored - handled by pull_request event.');
            }
        }
        
        // Special handling for main branch
        if (branchName === config.deployment.main_branch) {
            console.log(`[${config.name}] Deploying to main production site (${config.deployment.main_branch} branch)...`);
            setTimeout(() => {
                executeDeployment('./deploy-main-site.sh', [req.body.deleted], config);
            }, 5000);
        } else {
            // For other branches without PRs, use regular deployment
            console.log(`[${config.name}] Deploying non-PR branch: ${branchName}`);
            executeDeployment('./deploy-branch.sh', [branchName, sanitizedBranchName, req.body.deleted], config);
        }

        res.status(202).send('Accepted: Build process started.');
    } else if (event === 'pull_request') {
        // Handle pull request events
        const action = req.body.action;
        const pr = req.body.pull_request;
        
        // Process PR events that indicate branch updates
        if (['opened', 'synchronize', 'reopened'].includes(action)) {
            const branchName = pr.head.ref;
            const sanitizedBranchName = ensureSubdomainLength(branchName, config.deployment.branch_subdomain_prefix);
            const prNumber = pr.number;
            
            console.log(`[${config.name}] Received pull_request event (${action}) for branch: ${branchName} (PR #${prNumber})`);
            
            // Deploy the PR branch with PR commenting
            executeDeployment('./deploy-with-gh-comment.sh', [
                branchName,
                sanitizedBranchName,
                'false',
                prNumber,
                config.repo.owner,
                config.repo.name,
                config.name  // Pass deployment name for customized messages
            ], config);
            
            res.status(202).send('Accepted: Build process started for PR branch.');
        } else if (action === 'closed') {
            // If PR is closed, clean up the deployment
            const branchName = pr.head.ref;
            const sanitizedBranchName = ensureSubdomainLength(branchName, config.deployment.branch_subdomain_prefix);
            const prNumber = pr.number;
            
            console.log(`[${config.name}] Received pull_request closed event for branch: ${branchName} (PR #${prNumber})`);
            
            // Mark branch as deleted to trigger cleanup
            executeDeployment('./deploy-with-gh-comment.sh', [
                branchName,
                sanitizedBranchName,
                'true',
                prNumber,
                config.repo.owner,
                config.repo.name,
                config.name
            ], config);
            
            res.status(202).send('Accepted: Cleanup process started for closed PR.');
        } else {
            console.log(`[${config.name}] Received pull_request event with action: ${action}, ignoring.`);
            res.status(200).send(`Pull request action '${action}' not handled.`);
        }
    } else {
        res.status(200).send('Event not handled.');
    }
});

// Health check endpoint
app.get('/health', (req, res) => {
    const configs = configManager.getAllConfigs();
    res.json({
        status: 'healthy',
        port: PORT,
        deployments: configs.map(c => ({
            name: c.name,
            repository: c.repo.fullName,
            base_domain: c.deployment.base_domain
        }))
    });
});

app.listen(PORT, () => {
    console.log(`Multi-repo webhook listener running on http://localhost:${PORT}`);
    console.log(`Loaded ${configManager.getAllConfigs().length} deployment configurations`);
});