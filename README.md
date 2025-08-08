# MCP Webhook Listener

A flexible webhook listener that automatically deploys GitHub repositories on push and pull request events. Supports multiple repositories with isolated configurations.

## Features

- **Multi-repository support** - Deploy multiple repos from a single instance
- **Automatic branch deployments** - Each branch gets its own subdomain
- **Pull request previews** - Automatic deployment and GitHub comments on PRs
- **Environment isolation** - Each deployment can have its own environment variables
- **Flexible configuration** - YAML-based configuration for each repository

## Quick Start

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Configure your deployments:**
   Create a YAML file in the `deployments/` directory for each repository:
   ```yaml
   name: your-app
   repo_url: git@github.com:yourorg/yourrepo.git
   webhook_secret: your-secret-here
   deployment:
     base_domain: yourdomain.com
     base_dir: /var/www/your-app
     main_branch: main
     branch_subdomain_prefix: preview-
   ```

3. **Start the listener:**
   ```bash
   npm start
   ```

4. **Configure GitHub webhooks:**
   - Go to your repository settings → Webhooks
   - Add webhook URL: `http://your-server:8081/webhook`
   - Secret: Use the `webhook_secret` from your YAML config
   - Events: Select "Pushes" and "Pull requests"

## Configuration

Each repository needs a YAML configuration file in the `deployments/` directory:

```yaml
name: app-name                                    # Deployment identifier
repo_url: git@github.com:owner/repo.git          # Repository URL (SSH or HTTPS)
webhook_secret: your-webhook-secret              # GitHub webhook secret
deployment:
  base_domain: example.com                       # Domain for deployments
  base_dir: /var/www/app-name                   # Base directory for files
  main_branch: main                              # Main/production branch
  branch_subdomain_prefix: preview-              # Prefix for branch subdomains
  production_branches: [main, production]        # Branches to treat as production
build:
  commands:                                      # Build commands (optional)
    - npm install
    - npm run build
  env_file: .env.app-name                       # Environment file (optional)
```

## Deployment Structure

```
/var/www/your-app/
├── repo/         # Git repository clone
├── main/         # Production build (main branch)
└── branches/     # Feature branch builds
    ├── feature-x/
    └── feature-y/
```

## URLs

- **Production:** `https://yourdomain.com`
- **Feature branches:** `https://preview-feature-name.yourdomain.com`

## Environment Variables

Place environment files in the root directory:
- `.env.{deployment-name}` - Per-deployment environment variables
- `.env` - Fallback environment variables

## Commands

- `npm start` - Start the webhook listener
- `npm stop` - Stop the webhook listener
- `npm restart` - Restart the webhook listener
- `npm run status` - Check listener status
- `npm run logs` - View listener logs


## Health Check

```bash
curl http://localhost:8081/health
```

Returns the status and list of configured deployments.

## Adding a New Repository

1. Copy `deployments/example-app.yaml.template`
2. Rename and configure with your repository details
3. Create `.env.{app-name}` if needed
4. Add webhook in GitHub repository settings
5. Restart the listener: `npm restart`

## Security Notes

- Each repository should have a unique webhook secret
- Webhook signatures are verified for every request
- Environment variables are isolated per deployment
- Use HTTPS for production webhook endpoints

## Troubleshooting

- Check logs: `npm run logs`
- Verify webhook delivery in GitHub settings
- Ensure directories have proper permissions
- Check that `gh` CLI is authenticated for PR features