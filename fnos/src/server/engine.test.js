'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { once } = require('node:events');
const { Engine } = require('./engine');
const { DEFAULT_SETTINGS } = require('./settings');

test('builtin process uses its writable data directory as HOME', async (t) => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ariapilot-home-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const bin = path.join(dir, 'aria2c');
  fs.writeFileSync(bin, '#!/bin/sh\nprintf "%s" "$HOME" > "$0.home"\n', { mode: 0o755 });
  const engine = new Engine({
    binPath: bin, confPath: path.join(dir, 'aria2.conf'), dataDir: dir, logDir: dir,
  });
  engine.spawnProcess();
  const [code, signal] = await once(engine.child, 'close');
  assert.equal(code, 0);
  assert.equal(signal, null);
  assert.equal(fs.readFileSync(`${bin}.home`, 'utf8'), dir);
});

test('builtin engine skips an occupied port even when it answers aria2 RPC', async (t) => {
  let requests = 0;
  const server = http.createServer((req, res) => {
    requests += 1;
    req.resume();
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({ jsonrpc: '2.0', id: '1', result: { version: '1.36.0' } }));
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const port = server.address().port;
  const engine = new Engine({ binPath: '', confPath: '', dataDir: '/tmp', logDir: '/tmp' });
  const picked = await engine.pickPort({ rpcPort: port, rpcSecret: 'app-secret' });
  assert.ok(picked.port > port, 'must choose a different port for its own process');
  assert.equal(requests, 0, 'must not contact the unrelated RPC service');
});

for (const executable of [true, false]) {
  test(`startup reports ${executable ? 'early exit and stderr' : 'spawn permission failure'}`, async (t) => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ariapilot-engine-'));
    t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
    const bin = path.join(dir, 'aria2c');
    fs.writeFileSync(bin, '#!/bin/sh\necho "startup fixture failure" >&2\nexit 7\n', {
      mode: executable ? 0o755 : 0o644,
    });
    const engine = new Engine({
      binPath: bin, confPath: path.join(dir, 'aria2.conf'), dataDir: dir, logDir: dir,
    });
    const status = await engine.start({ ...DEFAULT_SETTINGS, downloadDir: dir });
    assert.equal(status.state, 'error');
    if (executable) {
      assert.match(status.error, /code=7/);
      assert.match(status.error, /startup fixture failure/);
    } else {
      assert.match(status.error, /EACCES/);
    }
  });
}
