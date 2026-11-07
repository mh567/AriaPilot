'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { Aria2Error } = require('./aria2');
const { PathError } = require('./paths');
const { SettingsError } = require('./settings');

const PUBLIC_DIR = path.join(__dirname, '..', 'public');
const JSON_LIMIT = 1024 * 1024;
const TASK_LIMIT = 30 * 1024 * 1024;
const MAX_TORRENT_BYTES = 20 * 1024 * 1024;

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
  '.json': 'application/json; charset=utf-8',
  '.woff2': 'font/woff2',
};

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.name = 'HttpError';
    this.status = status;
  }
}

function sendJson(res, status, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
    'Cache-Control': 'no-store',
  });
  res.end(body);
}

function readJson(req, limit) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    let finished = false;

    req.on('data', (chunk) => {
      if (finished) return;
      size += chunk.length;
      if (size > limit) {
        finished = true;
        chunks.length = 0;
        reject(new HttpError(413, '请求内容过大'));
        req.resume();
        return;
      }
      chunks.push(chunk);
    });

    req.on('end', () => {
      if (finished) return;
      finished = true;
      const text = Buffer.concat(chunks).toString('utf8');
      if (!text.trim()) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(text));
      } catch {
        reject(new HttpError(400, '请求内容不是合法 JSON'));
      }
    });

    req.on('error', (error) => {
      if (finished) return;
      finished = true;
      reject(error);
    });
  });
}

function isMissingTaskError(message) {
  const text = String(message || '').toLowerCase();
  return (
    text.includes('not found') ||
    text.includes('notfound') ||
    text.includes('no such') ||
    text.includes('unknown')
  );
}

function sendError(res, error) {
  if (res.headersSent) {
    try {
      res.end();
    } catch {
      /* stream already closed */
    }
    return;
  }

  let status = 500;
  if (error instanceof HttpError) status = error.status;
  else if (error instanceof PathError || error instanceof SettingsError) status = 400;
  else if (error instanceof Aria2Error) status = 502;

  sendJson(res, status, {
    error: {
      code: error.name || 'Error',
      message: error.message || '未知错误',
    },
  });
}

function serveStatic(req, res, pathname) {
  let relative;
  try {
    relative = decodeURIComponent(pathname);
  } catch {
    throw new HttpError(400, '路径格式不正确');
  }

  if (relative === '/' || relative === '') relative = '/index.html';
  const file = path.join(PUBLIC_DIR, relative.replace(/^\/+/, ''));

  if (file !== PUBLIC_DIR && !file.startsWith(`${PUBLIC_DIR}${path.sep}`)) {
    throw new HttpError(403, '禁止访问');
  }

  fs.readFile(file, (error, data) => {
    if (error) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('Not found');
      return;
    }
    const type = MIME_TYPES[path.extname(file).toLowerCase()] || 'application/octet-stream';
    res.writeHead(200, {
      'Content-Type': type,
      'Content-Length': data.length,
      'Cache-Control': 'no-store',
    });
    res.end(data);
  });
}

function handleEvents(req, res, ctx) {
  res.writeHead(200, {
    'Content-Type': 'text/event-stream; charset=utf-8',
    'Cache-Control': 'no-store',
    Connection: 'keep-alive',
    'X-Accel-Buffering': 'no',
  });
  res.write('retry: 3000\n\n');

  let closed = false;
  let busy = false;

  const send = async () => {
    if (closed || busy) return;
    busy = true;
    try {
      const snapshot = await ctx.getSnapshot({ loaded: 20 });
      if (!closed) {
        res.write(`event: snapshot\ndata: ${JSON.stringify(snapshot)}\n\n`);
      }
    } catch (error) {
      if (!closed) {
        res.write(
          `event: error\ndata: ${JSON.stringify({ message: error.message })}\n\n`,
        );
      }
    } finally {
      busy = false;
    }
  };

  const timer = setInterval(send, 1500);
  const heartbeat = setInterval(() => {
    if (!closed) res.write(': ping\n\n');
  }, 15000);

  const close = () => {
    if (closed) return;
    closed = true;
    clearInterval(timer);
    clearInterval(heartbeat);
    try {
      res.end();
    } catch {
      /* stream already closed */
    }
  };

  req.on('close', close);
  req.on('error', close);
  send();
}

async function handleApi(req, res, url, ctx) {
  const method = req.method || 'GET';
  const pathname = url.pathname;

  if (method === 'GET' && pathname === '/api/events') {
    handleEvents(req, res, ctx);
    return;
  }

  if (method === 'GET' && pathname === '/api/health') {
    sendJson(res, 200, {
      ok: true,
      version: ctx.appVersion,
      uptime: Math.round(process.uptime()),
      engine: ctx.getEngineStatus(),
      roots: ctx.paths.roots,
    });
    return;
  }

  if (method === 'GET' && pathname === '/api/snapshot') {
    const loaded = Number(url.searchParams.get('loaded')) || 20;
    sendJson(res, 200, await ctx.getSnapshot({ loaded }));
    return;
  }

  if (method === 'GET' && pathname === '/api/tasks') {
    const loaded = Number(url.searchParams.get('loaded')) || 20;
    const tab = url.searchParams.get('tab') || 'active';
    const snapshot = await ctx.getSnapshot({ loaded });
    if (tab === 'stopped') {
      sendJson(res, 200, {
        stopped: snapshot.stopped,
        stoppedTotal: snapshot.stoppedTotal,
        hasMoreStopped: snapshot.hasMoreStopped,
        engine: snapshot.engine,
      });
      return;
    }
    sendJson(res, 200, {
      active: snapshot.active,
      waiting: snapshot.waiting,
      global: snapshot.global,
      engine: snapshot.engine,
    });
    return;
  }

  if (method === 'GET' && pathname === '/api/settings') {
    sendJson(res, 200, {
      settings: ctx.getPublicSettings(),
      engine: ctx.getEngineStatus(),
      roots: ctx.paths.roots,
      warnings: ctx.getWarnings(),
    });
    return;
  }

  if (method === 'PUT' && pathname === '/api/settings') {
    const body = await readJson(req, JSON_LIMIT);
    if (!body || typeof body !== 'object' || Array.isArray(body)) {
      throw new HttpError(400, '请求内容必须是 JSON 对象');
    }
    const result = await ctx.saveSettings(body);
    ctx.invalidateSnapshot();
    sendJson(res, 200, result);
    return;
  }

  if (method === 'GET' && pathname === '/api/fs/roots') {
    sendJson(res, 200, { roots: ctx.paths.roots });
    return;
  }

  if (method === 'GET' && pathname === '/api/fs/list') {
    const dir = url.searchParams.get('path') || '';
    sendJson(res, 200, ctx.paths.list(dir));
    return;
  }

  if (method === 'POST' && pathname === '/api/tasks') {
    const body = await readJson(req, TASK_LIMIT);
    const settings = ctx.getSettings();
    const client = ctx.getClient();

    const options = {
      split: String(settings.split),
      'max-connection-per-server': String(settings.connectionsPerServer),
    };

    let dir = typeof body.dir === 'string' ? body.dir.trim() : '';
    if (!dir) dir = settings.downloadDir;
    if (dir) {
      if (settings.mode === 'builtin') dir = ctx.paths.ensureDirectory(dir);
      options.dir = dir;
    }

    const gids = [];

    if (body.torrentBase64) {
      const base64 = String(body.torrentBase64).replace(/\s+/g, '');
      if (!/^[A-Za-z0-9+/]+={0,2}$/.test(base64)) {
        throw new HttpError(400, '种子文件内容不是合法 base64');
      }
      const torrent = Buffer.from(base64, 'base64');
      if (torrent.length === 0 || torrent[0] !== 0x64) {
        throw new HttpError(400, '种子文件格式不正确');
      }
      if (torrent.length > MAX_TORRENT_BYTES) {
        throw new HttpError(413, '种子文件不能超过 20 MB');
      }
      gids.push(await client.addTorrent(base64, options));
    }

    const uris = Array.isArray(body.uris) ? body.uris : [];
    if (uris.length > 20) {
      throw new HttpError(400, '一次最多添加 20 个链接');
    }
    for (const raw of uris) {
      const uri = typeof raw === 'string' ? raw.trim() : '';
      if (!uri) continue;
      if (uri.length > 8192) throw new HttpError(400, '下载链接过长');
      gids.push(await client.addUri([uri], options));
    }

    if (gids.length === 0) {
      throw new HttpError(400, '请填写下载链接或选择种子文件');
    }

    ctx.invalidateSnapshot();
    sendJson(res, 200, { gids });
    return;
  }

  const actionMatch = pathname.match(/^\/api\/tasks\/([0-9a-zA-Z]+)\/(pause|resume)$/);
  if (method === 'POST' && actionMatch) {
    const [, gid, action] = actionMatch;
    const client = ctx.getClient();
    const result =
      action === 'pause' ? await client.pause(gid) : await client.unpause(gid);
    ctx.invalidateSnapshot();
    sendJson(res, 200, { gid: result || gid, action });
    return;
  }

  const taskMatch = pathname.match(/^\/api\/tasks\/([0-9a-zA-Z]+)$/);
  if (method === 'DELETE' && taskMatch) {
    const gid = taskMatch[1];
    const settings = ctx.getSettings();
    const client = ctx.getClient();
    const deleteFiles = url.searchParams.get('deleteFiles') === '1';

    let task = null;
    try {
      task = await client.tellStatus(gid);
    } catch {
      /* task may already be gone */
    }

    try {
      await client.remove(gid);
    } catch (error) {
      try {
        await client.removeDownloadResult(gid);
      } catch (fallbackError) {
        if (!isMissingTaskError(fallbackError.message)) throw fallbackError;
      }
    }

    let fileResult = null;
    if (deleteFiles) {
      if (settings.mode !== 'builtin') {
        throw new HttpError(400, '外部 aria2 模式不支持删除远端文件');
      }
      fileResult = ctx.paths.deleteFiles(
        (task && task.files) || [],
        (task && task.dir) || settings.downloadDir,
      );
    }

    ctx.history.remove(gid);
    ctx.invalidateSnapshot();
    sendJson(res, 200, { removed: gid, files: fileResult });
    return;
  }

  if (method === 'POST' && pathname === '/api/history/purge') {
    try {
      await ctx.getClient().purgeDownloadResult();
    } catch {
      /* engine may be offline, history still clears */
    }
    ctx.history.purge();
    ctx.invalidateSnapshot();
    sendJson(res, 200, { ok: true });
    return;
  }

  if (method === 'POST' && pathname === '/api/engine/restart') {
    if (ctx.getSettings().mode !== 'builtin') {
      throw new HttpError(400, '当前使用外部 aria2，无法重启内置引擎');
    }
    await ctx.restartEngine();
    ctx.invalidateSnapshot();
    sendJson(res, 200, { engine: ctx.getEngineStatus() });
    return;
  }

  if (method === 'GET' && pathname === '/api/logs/tail') {
    const lines = Math.min(200, Math.max(1, Number(url.searchParams.get('lines')) || 50));
    sendJson(res, 200, {
      path: ctx.getEngineStatus().logPath,
      lines: ctx.engineLogTail(lines),
    });
    return;
  }

  throw new HttpError(404, '接口不存在');
}

function createRouter(ctx) {
  return async function route(req, res) {
    try {
      const url = new URL(req.url || '/', 'http://localhost');
      if (url.pathname.startsWith('/api/')) {
        await handleApi(req, res, url, ctx);
        return;
      }
      serveStatic(req, res, url.pathname);
    } catch (error) {
      sendError(res, error);
    }
  };
}

module.exports = { createRouter, HttpError };
