import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import http from 'node:http';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '../..');
const SERVER = path.join(ROOT, 'fnos/src/server/index.js');
const ARIA2_BIN = path.join(ROOT, 'vendor/aria2/darwin-arm64/aria2c');
const ARIA2_LIB = path.join(ROOT, 'vendor/aria2/darwin-arm64/lib');

const work = fs.mkdtempSync(path.join(os.tmpdir(), 'ariapilot-smoke-'));
const dataDir = path.join(work, 'data');
const rootA = path.join(work, 'rootA');
const rootB = path.join(work, 'rootB');
const sharePath = path.join(work, 'appshare', 'ariapilot', 'downloads');
fs.mkdirSync(rootA, { recursive: true });
fs.mkdirSync(rootB, { recursive: true });
fs.mkdirSync(sharePath, { recursive: true });

const fastFile = path.join(work, 'fast.bin');
const slowFile = path.join(work, 'slow.bin');
writePseudoRandom(fastFile, 2 * 1024 * 1024, 7);
writePseudoRandom(slowFile, 4 * 1024 * 1024, 11);

let app = null;
let appLogs = '';
let appPort = 0;
let fixturePort = 0;
let baseUrl = '';

const fixture = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  const file =
    url.pathname === '/fast.bin'
      ? fastFile
      : url.pathname === '/slow.bin'
        ? slowFile
        : null;

  if (!file) {
    res.writeHead(404);
    res.end('not found');
    return;
  }

  const stat = fs.statSync(file);
  const range = req.headers.range;
  let start = 0;
  let end = stat.size - 1;
  let status = 200;

  if (range) {
    const match = /^bytes=(\d+)-(\d*)$/.exec(range);
    if (match) {
      start = Number(match[1]);
      if (match[2]) end = Math.min(stat.size - 1, Number(match[2]));
      status = 206;
    }
  }

  if (start >= stat.size) {
    res.writeHead(416, { 'Content-Range': `bytes */${stat.size}` });
    res.end();
    return;
  }

  const headers = {
    'Content-Type': 'application/octet-stream',
    'Accept-Ranges': 'bytes',
    'Content-Length': end - start + 1,
  };
  if (status === 206) {
    headers['Content-Range'] = `bytes ${start}-${end}/${stat.size}`;
  }
  res.writeHead(status, headers);

  const stream = fs.createReadStream(file, {
    start,
    end,
    highWaterMark: url.pathname === '/slow.bin' ? 256 * 1024 : 64 * 1024,
  });

  if (url.pathname !== '/slow.bin') {
    stream.pipe(res);
    return;
  }

  stream.on('data', (chunk) => {
    stream.pause();
    res.write(chunk);
    setTimeout(() => {
      if (!res.destroyed) stream.resume();
    }, 120);
  });
  stream.on('end', () => res.end());
  stream.on('error', () => res.destroy());
  req.on('close', () => stream.destroy());
});

function writePseudoRandom(file, size, seed) {
  const buffer = Buffer.alloc(size);
  let value = seed;
  for (let index = 0; index < size; index += 1) {
    value = (value * 1103515245 + 12345) & 0x7fffffff;
    buffer[index] = value & 0xff;
  }
  fs.writeFileSync(file, buffer);
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function getFreePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.once('error', reject);
    server.listen(0, '127.0.0.1', () => {
      const { port } = server.address();
      server.close(() => resolve(port));
    });
  });
}

function startApp() {
  const env = {
    ...process.env,
    AP_DEST: path.join(ROOT, 'fnos/src'),
    AP_VAR: dataDir,
    AP_PORT: String(appPort),
    AP_ARIA2_BIN: ARIA2_BIN,
    AP_AUTH_PATHS: `${rootA}:${rootB}`,
    AP_SHARE_PATHS: sharePath,
  };

  if (fs.existsSync(ARIA2_LIB)) env.DYLD_LIBRARY_PATH = ARIA2_LIB;

  app = spawn(process.execPath, [SERVER], {
    env,
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  app.stdout.on('data', (chunk) => {
    appLogs += chunk.toString();
  });
  app.stderr.on('data', (chunk) => {
    appLogs += chunk.toString();
  });

  return app;
}

function stopApp() {
  return new Promise((resolve) => {
    if (!app || app.exitCode !== null) {
      resolve();
      return;
    }

    const timer = setTimeout(() => {
      try {
        app.kill('SIGKILL');
      } catch {
        /* already gone */
      }
      resolve();
    }, 12000);

    app.once('exit', () => {
      clearTimeout(timer);
      resolve();
    });
    app.kill('SIGTERM');
  });
}

async function call(pathname, options = {}) {
  const response = await fetch(`${baseUrl}${pathname}`, {
    cache: 'no-store',
    ...options,
  });
  const text = await response.text();
  let body = text;
  try {
    body = JSON.parse(text);
  } catch {
    /* plain text response */
  }
  return { status: response.status, body };
}

async function postJson(pathname, payload) {
  return call(pathname, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload || {}),
  });
}

async function putJson(pathname, payload) {
  return call(pathname, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
}

async function waitFor(label, fn, { timeout = 30000, interval = 200 } = {}) {
  const deadline = Date.now() + timeout;
  let lastError = null;

  while (Date.now() < deadline) {
    try {
      const result = await fn();
      if (result) return result;
    } catch (error) {
      lastError = error;
    }
    await delay(interval);
  }

  throw new Error(
    `等待超时：${label}${lastError ? `（${lastError.message}）` : ''}\n--- 应用日志 ---\n${appLogs}`,
  );
}

async function snapshot() {
  const response = await call('/api/snapshot');
  assert.equal(response.status, 200, JSON.stringify(response.body));
  return response.body;
}

function findTask(snap, gid) {
  return [...(snap.active || []), ...(snap.waiting || []), ...(snap.stopped || [])].find(
    (task) => task.gid === gid,
  );
}

async function addTask(uri, dir) {
  const payload = { uris: [uri] };
  if (dir) payload.dir = dir;
  const response = await postJson('/api/tasks', payload);
  assert.equal(response.status, 200, JSON.stringify(response.body));
  assert.equal(response.body.gids.length, 1);
  return response.body.gids[0];
}

async function waitComplete(gid, timeout = 45000) {
  return waitFor(
    `任务 ${gid} 完成`,
    async () => {
      const snap = await snapshot();
      const task = findTask(snap, gid);
      return task && task.status === 'complete' ? task : null;
    },
    { timeout },
  );
}

function fileHash(file) {
  return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
}

async function readFirstSseFrame() {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 6000);

  try {
    const response = await fetch(`${baseUrl}/api/events`, {
      signal: controller.signal,
    });
    assert.equal(response.status, 200);
    assert.match(response.headers.get('content-type') || '', /event-stream/);

    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let text = '';

    while (!text.includes('event: snapshot')) {
      const { value, done } = await reader.read();
      if (done) break;
      text += decoder.decode(value, { stream: true });
      if (text.length > 200000) break;
    }

    await reader.cancel();
    return text;
  } finally {
    clearTimeout(timer);
  }
}

async function main() {
  assert.equal(fs.existsSync(ARIA2_BIN), true, `缺少 aria2：${ARIA2_BIN}`);

  fixturePort = await getFreePort();
  appPort = await getFreePort();
  baseUrl = `http://127.0.0.1:${appPort}`;

  await new Promise((resolve) => fixture.listen(fixturePort, '127.0.0.1', resolve));
  const fixtureBase = `http://127.0.0.1:${fixturePort}`;

  console.log('1. 启动应用与内置 aria2');
  startApp();

  await waitFor('HTTP 健康检查', async () => {
    const response = await call('/api/health');
    return response.status === 200 ? response.body : null;
  }, { timeout: 20000 });

  console.log('1.1 并发重启验证');
  const [restartA, restartB] = await Promise.all([
    postJson('/api/engine/restart'),
    postJson('/api/engine/restart'),
  ]);
  assert.equal(restartA.status, 200, JSON.stringify(restartA.body));
  assert.equal(restartB.status, 200, JSON.stringify(restartB.body));
  assert.equal(restartA.body.engine.state, 'running');
  assert.equal(restartB.body.engine.state, 'running');
  assert.equal(restartA.body.engine.error, '');

  await waitFor('aria2 引擎就绪', async () => {
    const snap = await snapshot();
    return snap.engine && snap.engine.state === 'running' ? snap.engine : null;
  }, { timeout: 30000 });

  const settingsResponse = await call('/api/settings');
  assert.equal(settingsResponse.status, 200);
  assert.equal(settingsResponse.body.settings.mode, 'builtin');
  assert.equal(settingsResponse.body.settings.rpcSecret, undefined);
  assert.ok(settingsResponse.body.roots.length >= 2);
  assert.equal(
    settingsResponse.body.settings.downloadDir,
    fs.realpathSync(sharePath),
  );

  console.log('2. 添加 HTTP 任务并等待完成');
  const firstGid = await addTask(`${fixtureBase}/fast.bin`);
  const firstTask = await waitComplete(firstGid);
  const firstFile = firstTask.files[0].path;
  assert.equal(fs.existsSync(firstFile), true, firstFile);
  assert.equal(fileHash(firstFile), fileHash(fastFile));

  console.log('3. 校验 SSE 快照');
  const sse = await readFirstSseFrame();
  assert.match(sse, /event: snapshot/);

  console.log('4. 暂停与继续');
  const slowGid = await addTask(`${fixtureBase}/slow.bin`);
  await waitFor('慢速任务开始下载', async () => {
    const snap = await snapshot();
    const task = snap.active.find((item) => item.gid === slowGid);
    return task && task.completedLength > 0 ? task : null;
  });

  const pauseResponse = await postJson(`/api/tasks/${slowGid}/pause`);
  assert.equal(pauseResponse.status, 200, JSON.stringify(pauseResponse.body));

  await waitFor('任务进入暂停', async () => {
    const snap = await snapshot();
    const task = findTask(snap, slowGid);
    return task && (task.status === 'paused' || task.status === 'waiting' || task.isPaused)
      ? task
      : null;
  });

  const resumeResponse = await postJson(`/api/tasks/${slowGid}/resume`);
  assert.equal(resumeResponse.status, 200, JSON.stringify(resumeResponse.body));
  await waitComplete(slowGid);

  console.log('5. 修改下载目录并验证落盘位置');
  const newDir = path.join(rootB, 'Downloads');
  const putResponse = await putJson('/api/settings', { downloadDir: newDir });
  assert.equal(putResponse.status, 200, JSON.stringify(putResponse.body));
  const savedDir = putResponse.body.settings.downloadDir;
  assert.equal(savedDir, fs.realpathSync(newDir));

  const movedGid = await addTask(`${fixtureBase}/fast.bin`);
  const movedTask = await waitComplete(movedGid);
  const movedFile = movedTask.files[0].path;
  assert.equal(fs.existsSync(movedFile), true, movedFile);
  assert.ok(movedFile.startsWith(`${fs.realpathSync(rootB)}${path.sep}`), movedFile);

  const listResponse = await call(`/api/fs/list?path=${encodeURIComponent(rootA)}`);
  assert.equal(listResponse.status, 200, JSON.stringify(listResponse.body));

  console.log('6. 拒绝越权目录');
  const badResponse = await putJson('/api/settings', { downloadDir: '/etc' });
  assert.equal(badResponse.status, 400);
  assert.match(badResponse.body.error.message, /授权/);

  console.log('7. 删除任务与文件');
  const deleteResponse = await call(
    `/api/tasks/${movedGid}?deleteFiles=1`,
    { method: 'DELETE' },
  );
  assert.equal(deleteResponse.status, 200, JSON.stringify(deleteResponse.body));
  assert.equal(fs.existsSync(movedFile), false, movedFile);

  console.log('8. 重启后保留历史');
  const historyFile = path.join(dataDir, 'history.json');
  const history = JSON.parse(fs.readFileSync(historyFile, 'utf8'));
  assert.ok(history.some((item) => item.gid === firstGid));

  await stopApp();
  startApp();

  await waitFor('重启后 HTTP 可用', async () => {
    const response = await call('/api/health');
    return response.status === 200 ? response.body : null;
  }, { timeout: 20000 });

  await waitFor('重启后引擎就绪', async () => {
    const snap = await snapshot();
    return snap.engine && snap.engine.state === 'running' ? snap.engine : null;
  }, { timeout: 30000 });

  await waitFor('历史任务仍在', async () => {
    const snap = await snapshot();
    const task = findTask(snap, firstGid);
    return task && task.status === 'complete' ? task : null;
  });

  const finalSettings = await call('/api/settings');
  assert.equal(
    finalSettings.body.settings.downloadDir,
    fs.realpathSync(newDir),
  );

  console.log('9. 冒烟测试全部通过');
}

try {
  await main();
} catch (error) {
  console.error(error.stack || error.message);
  if (appLogs) console.error(`--- 应用日志 ---\n${appLogs}`);
  process.exitCode = 1;
} finally {
  await stopApp();
  await new Promise((resolve) => fixture.close(resolve));
  fs.rmSync(work, { recursive: true, force: true });
}
