module.exports = {
  apps: [{
    name: 'mcp-webhook-listener',
    script: './listener.js',
    cwd: '/root/mcp-webhook-listener',
    env: {
      NODE_ENV: 'production',
      GITHUB_TOKEN: process.env.GITHUB_TOKEN || '' // Will be set when running pm2
    },
    error_file: '~/.pm2/logs/mcp-webhook-listener-error.log',
    out_file: '~/.pm2/logs/mcp-webhook-listener-out.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss'
  }]
};