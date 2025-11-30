#!/usr/bin/env node
/**
 * Catalyst Example App
 * Demonstrates the catalyst-images base image features
 */

const http = require('http');
const os = require('os');

const PORT = process.env.PORT || 3000;

// Gather environment info
const getEnvironmentInfo = () => ({
  hostname: os.hostname(),
  platform: os.platform(),
  arch: os.arch(),
  cpus: os.cpus().length,
  memory: {
    total: `${Math.round(os.totalmem() / 1024 / 1024)} MB`,
    free: `${Math.round(os.freemem() / 1024 / 1024)} MB`,
  },
  uptime: `${Math.round(os.uptime() / 60)} minutes`,
  node: process.version,
  env: {
    SHELL: process.env.SHELL || 'unknown',
    EDITOR: process.env.EDITOR || 'unknown',
    TERM: process.env.TERM || 'unknown',
    CATALYST_ENV: process.env.CATALYST_ENV || 'not set',
    CONTAINER: process.env.CONTAINER || process.env.container || 'unknown',
  },
});

// ASCII art banner
const banner = `
╔═══════════════════════════════════════════════════════════════════╗
║                                                                    ║
║   ██████╗ █████╗ ████████╗ █████╗ ██╗  ██╗   ██╗███████╗████████╗ ║
║  ██╔════╝██╔══██╗╚══██╔══╝██╔══██║██║  ╚██╗ ██╔╝██╔════╝╚══██╔══╝ ║
║  ██║     ███████║   ██║   ███████║██║   ╚████╔╝ ███████╗   ██║    ║
║  ██║     ██╔══██║   ██║   ██╔══██║██║    ╚██╔╝  ╚════██║   ██║    ║
║  ╚██████╗██║  ██║   ██║   ██║  ██║███████╗██║   ███████║   ██║    ║
║   ╚═════╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝   ╚══════╝   ╚═╝    ║
║                                                                    ║
║              Example App - Running on catalyst-images                 ║
║                                                                    ║
╚═══════════════════════════════════════════════════════════════════╝
`;

// Create HTTP server
const server = http.createServer((req, res) => {
  const info = getEnvironmentInfo();

  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'healthy', timestamp: new Date().toISOString() }));
    return;
  }

  if (req.url === '/api/info') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(info, null, 2));
    return;
  }

  // Default HTML response
  res.writeHead(200, { 'Content-Type': 'text/html' });
  res.end(`
<!DOCTYPE html>
<html>
<head>
  <title>Catalyst Example App</title>
  <style>
    body {
      background: linear-gradient(135deg, #0f0c29 0%, #302b63 50%, #24243e 100%);
      color: #00ffff;
      font-family: 'Courier New', monospace;
      min-height: 100vh;
      margin: 0;
      padding: 20px;
    }
    pre {
      background: rgba(0, 0, 0, 0.5);
      padding: 20px;
      border-radius: 10px;
      border: 1px solid #ff00ff;
      overflow-x: auto;
    }
    .banner {
      color: #ff00ff;
      text-shadow: 0 0 10px #ff00ff;
    }
    h2 {
      color: #ff00ff;
      text-shadow: 0 0 5px #ff00ff;
    }
    .info {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
      gap: 20px;
      margin-top: 20px;
    }
    .card {
      background: rgba(0, 0, 0, 0.3);
      border: 1px solid #00ffff;
      border-radius: 10px;
      padding: 15px;
    }
    .card h3 {
      color: #00ffff;
      margin-top: 0;
    }
    .value {
      color: #00ff00;
    }
  </style>
</head>
<body>
  <pre class="banner">${banner.replace(/</g, '&lt;').replace(/>/g, '&gt;')}</pre>

  <h2>Environment Information</h2>
  <div class="info">
    <div class="card">
      <h3>System</h3>
      <p>Hostname: <span class="value">${info.hostname}</span></p>
      <p>Platform: <span class="value">${info.platform} / ${info.arch}</span></p>
      <p>CPUs: <span class="value">${info.cpus}</span></p>
      <p>Uptime: <span class="value">${info.uptime}</span></p>
    </div>
    <div class="card">
      <h3>Memory</h3>
      <p>Total: <span class="value">${info.memory.total}</span></p>
      <p>Free: <span class="value">${info.memory.free}</span></p>
    </div>
    <div class="card">
      <h3>Runtime</h3>
      <p>Node: <span class="value">${info.node}</span></p>
      <p>Shell: <span class="value">${info.env.SHELL}</span></p>
      <p>Editor: <span class="value">${info.env.EDITOR}</span></p>
    </div>
    <div class="card">
      <h3>Container</h3>
      <p>Container: <span class="value">${info.env.CONTAINER}</span></p>
      <p>Catalyst Env: <span class="value">${info.env.CATALYST_ENV}</span></p>
      <p>Term: <span class="value">${info.env.TERM}</span></p>
    </div>
  </div>

  <h2>API Endpoints</h2>
  <pre>
GET /           - This page
GET /health     - Health check
GET /api/info   - JSON environment info
  </pre>
</body>
</html>
  `);
});

// Start server
server.listen(PORT, () => {
  console.log(banner);
  console.log(`\n🚀 Server running at http://localhost:${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
  console.log(`📋 API info: http://localhost:${PORT}/api/info\n`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully...');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});
