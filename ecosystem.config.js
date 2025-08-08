module.exports = {
  apps: [{
    name: 'mcp-webhook-listener',
    script: './listener.js',
    cwd: __dirname,
    env: {
      NODE_ENV: process.env.NODE_ENV || 'production',
      GITHUB_TOKEN: process.env.GITHUB_TOKEN || ''
    },
    error_file: '~/.pm2/logs/mcp-webhook-listener-error.log',
    out_file: '~/.pm2/logs/mcp-webhook-listener-out.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss',
    max_restarts: 10,
    min_uptime: 5000
  }]
};