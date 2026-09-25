const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

const host = process.env.HOST || '127.0.0.1';
const port = Number.parseInt(process.env.PORT || '3001', 10);
const indexPath = path.join(__dirname, 'public', 'index.html');
const startedAt = new Date().toISOString();

function createServer() {
  return http.createServer((request, response) => {
    const pathname = new URL(request.url, `http://${request.headers.host || 'localhost'}`).pathname;

    if (pathname === '/health') {
      response.writeHead(200, { 'content-type': 'application/json; charset=utf-8' });
      response.end(JSON.stringify({ status: 'ok' }));
      return;
    }

    if (pathname === '/api/status') {
      response.writeHead(200, { 'content-type': 'application/json; charset=utf-8' });
      response.end(JSON.stringify({ name: 'DevOps Monitoring Demo', status: 'running', startedAt }));
      return;
    }

    if (pathname === '/' || pathname === '/index.html') {
      fs.createReadStream(indexPath)
        .on('error', () => {
          response.writeHead(500, { 'content-type': 'text/plain; charset=utf-8' });
          response.end('Application page is unavailable');
        })
        .on('open', () => response.writeHead(200, { 'content-type': 'text/html; charset=utf-8' }))
        .pipe(response);
      return;
    }

    response.writeHead(404, { 'content-type': 'application/json; charset=utf-8' });
    response.end(JSON.stringify({ error: 'not_found' }));
  });
}

if (require.main === module) {
  const server = createServer();
  server.listen(port, host, () => console.log(`Application listening on http://${host}:${port}`));
  for (const signal of ['SIGINT', 'SIGTERM']) {
    process.on(signal, () => server.close(() => process.exit(0)));
  }
}

module.exports = { createServer };