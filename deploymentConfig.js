const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');

class DeploymentConfigManager {
    constructor(configDir = path.join(__dirname, 'deployments')) {
        this.configDir = configDir;
        this.configs = new Map();
        this.ensureConfigDir();
        this.loadAllConfigs();
    }

    ensureConfigDir() {
        if (!fs.existsSync(this.configDir)) {
            fs.mkdirSync(this.configDir, { recursive: true });
        }
    }

    parseRepoUrl(repoUrl) {
        // Parse both SSH and HTTPS formats
        // git@github.com:owner/repo.git -> owner/repo
        // https://github.com/owner/repo.git -> owner/repo
        const sshMatch = repoUrl.match(/git@[^:]+:([^/]+)\/([^.]+)(?:\.git)?$/);
        if (sshMatch) {
            return {
                owner: sshMatch[1],
                name: sshMatch[2],
                fullName: `${sshMatch[1]}/${sshMatch[2]}`
            };
        }

        const httpMatch = repoUrl.match(/https?:\/\/[^/]+\/([^/]+)\/([^/.]+)(?:\.git)?$/);
        if (httpMatch) {
            return {
                owner: httpMatch[1],
                name: httpMatch[2],
                fullName: `${httpMatch[1]}/${httpMatch[2]}`
            };
        }

        throw new Error(`Invalid repository URL format: ${repoUrl}`);
    }

    loadConfig(filename) {
        try {
            const filePath = path.join(this.configDir, filename);
            const fileContent = fs.readFileSync(filePath, 'utf8');
            const config = yaml.load(fileContent);

            // Parse repo info from URL
            const repoInfo = this.parseRepoUrl(config.repo_url);
            config.repo = repoInfo;

            // Ensure required fields
            if (!config.name || !config.repo_url || !config.webhook_secret) {
                console.error(`Invalid config in ${filename}: missing required fields`);
                return null;
            }

            // Set defaults
            config.deployment = config.deployment || {};
            config.deployment.main_branch = config.deployment.main_branch || 'master';
            config.deployment.branch_subdomain_prefix = config.deployment.branch_subdomain_prefix || 'dev-';
            config.deployment.production_branches = config.deployment.production_branches || ['master', 'main'];

            // Store by repo full name for easy lookup
            this.configs.set(repoInfo.fullName, config);
            console.log(`Loaded deployment config for ${repoInfo.fullName}`);
            return config;
        } catch (error) {
            console.error(`Error loading config ${filename}:`, error.message);
            return null;
        }
    }

    loadAllConfigs() {
        const files = fs.readdirSync(this.configDir)
            .filter(file => file.endsWith('.yaml') || file.endsWith('.yml'));

        files.forEach(file => this.loadConfig(file));
        console.log(`Loaded ${this.configs.size} deployment configurations`);
    }

    getConfig(repoFullName) {
        return this.configs.get(repoFullName);
    }

    getAllConfigs() {
        return Array.from(this.configs.values());
    }

    getConfigByWebhookSecret(secret) {
        for (const config of this.configs.values()) {
            if (config.webhook_secret === secret) {
                return config;
            }
        }
        return null;
    }

    // Helper to generate environment variables for deployment scripts
    getDeploymentEnv(config) {
        const env = {
            DEPLOY_BASE_DOMAIN: config.deployment.base_domain,
            DEPLOY_BASE_DIR: config.deployment.base_dir,
            DEPLOY_REPO_URL: config.repo_url,
            DEPLOY_MAIN_BRANCH: config.deployment.main_branch,
            DEPLOY_BRANCH_SUBDOMAIN_PREFIX: config.deployment.branch_subdomain_prefix,
            REPO_OWNER: config.repo.owner,
            REPO_NAME: config.repo.name,
            PRODUCTION_BRANCHES: config.deployment.production_branches.join(','),
            DEPLOYMENT_NAME: config.name
        };

        // Add derived paths
        env.REPO_CLONE_DIR = path.join(config.deployment.base_dir, 'repo');
        env.MAIN_SITE_DIR = path.join(config.deployment.base_dir, 'main');
        env.BRANCHES_BASE_DIR = path.join(config.deployment.base_dir, 'branches');

        // Add build-specific env if exists
        if (config.build && config.build.env_file) {
            env.BUILD_ENV_FILE = path.join(this.configDir, '..', config.build.env_file);
        }

        return env;
    }
}

module.exports = DeploymentConfigManager;