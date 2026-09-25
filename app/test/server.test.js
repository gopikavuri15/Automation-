const test = require('node:test');
const assert = require('node:assert/strict');
const { createServer } = require('../src/server');

test('serves the health endpoint', async (context) => {
  const server = createServer();
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  context.after(() => new Promise((resolve) => server.close(resolve)));

  const response = await fetch(`http://127.0.0.1:${server.address().port}/health`);
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { status: 'ok' });
});

test('serves application status and returns 404 for unknown routes', async (context) => {
  const server = createServer();
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  context.after(() => new Promise((resolve) => server.close(resolve)));
  const origin = `http://127.0.0.1:${server.address().port}`;

  const statusResponse = await fetch(`${origin}/api/status`);
  assert.equal(statusResponse.status, 200);
  assert.equal((await statusResponse.json()).status, 'running');

  const missingResponse = await fetch(`${origin}/missing`);
  assert.equal(missingResponse.status, 404);
});