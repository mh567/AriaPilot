'use strict';

const fs = require('node:fs');
const http = require('node:http');
const os = require('node:os');
const path = require('node:path');

const { Aria2Client } = require('./aria2');
const { Engine } = require('./engine');
const { HistoryStore } = require('./history');
const { AuthorizedPaths, isPathInside, splitPaths } = require('./paths');
const { createRouter } = require('./router');
const { SnapshotService } = require('./snapshot');
const {
  DEFAULT_SETTINGS,
  SettingsStore,
  makeSecret,
  normalizeSettings,
  publicSettings,
  resolveLegacyShareDir,
  validateSettings,
} = require('./settings');

const APP_VERSION = '1.0.7';

const appDest =
  process.env.AP_DEST ||
  process.env.TRIM_APPDEST ||
  path.resolve(__dirname, '..');
const appVar =
  process.env.AP_VAR ||
  process.env.TRIM_PKGVAR ||
  path.join(os.tmpdir(), 'ariapilot-fnos-dev');
const appEtc =
  process.env.AP_ETC ||
  process.env.TRIM_PKGETC ||
  path.join(appVar, 'etc');
const logDir = path.join(appVar, 'logs');
const listenPort = Number(
  process.env.AP_PORT || process.env.TRIM_SERVICE_PORT || 7788,
);
const authPathList = splitPaths(
  process.env.AP_AUTH_PATHS || process.env.TRIM_DATA_ACCESSIBLE_PATHS || '',
);
const sharePathList = splitPaths(
  process.env.AP_SHARE_PATHS || process.env.TRIM_DATA_SHARE_PATHS || '',
);
const aria2Bin =
  process.env.AP_ARIA2_BIN || path.join(appDest, 'bin', 'aria2', 'aria2c');

fs.mkdirSync(appVar, { recursive: true });
fs.mkdirSync(appEtc, { recursive: true });
fs.mkdirSync(logDir, { recursive: true });

const paths = new AuthorizedPaths({
  envPaths: authPathList,
  sharePaths: sharePathList,
  extraFile: path.join(appVar, 'auth_paths'),
});
paths.addFallback(path.join(appVar, 'downloads'));

const settingsStore = new SettingsStore(path.join(appVar, 'settings.json'));
let settings = normalizeSettings(settingsStore.load() || DEFAULT_SETTINGS);
if (!settings.rpcSecret) settings.rpcSecret = makeSecret();
let legacyDownloadDir = '';

function migrateLegacyDownloadDir(dir) {
  const result = resolveLegacyShareDir(dir, sharePathList);
  if (result.legacy) legacyDownloadDir = result.legacy;
  return result.dir;
}

function defaultDirectory() {
  const candidates = [];
  if (sharePathList[0]) candidates.push(sharePathList[0]);
  if (paths.roots[0]) candidates.push(path.join(paths.roots[0], 'AriaPilot'));
  candidates.push(path.join(appVar, 'downloads'));

  if (settings.downloadDir && paths.contains(settings.downloadDir)) {
    return settings.downloadDir;
  }
  for (const candidate of candidates) {
    if (paths.contains(candidate)) return candidate;
  }
  return path.join(appVar, 'downloads');
}

settings.downloadDir = migrateLegacyDownloadDir(settings.downloadDir);
settings.downloadDir = defaultDirectory();
try {
  settings.downloadDir = paths.ensureDirectory(settings.downloadDir);
} catch {
  settings.downloadDir = path.join(appVar, 'downloads');
  fs.mkdirSync(settings.downloadDir, { recursive: true });
}
settingsStore.save(settings);

const history = new HistoryStore(path.join(appVar, 'history.json'));
const engine = new Engine({
  binPath: aria2Bin,
  confPath: path.join(appEtc, 'aria2.conf'),
  dataDir: path.join(appVar, 'aria2'),
  logDir,
});

function getClient() {
  if (settings.mode === 'external') {
    return new Aria2Client({
      url: settings.externalRpcUrl,
      secret: settings.externalRpcSecret,
    });
  }
  return new Aria2Client({
    url: `http://127.0.0.1:${engine.port || settings.rpcPort}/jsonrpc`,
    secret: settings.rpcSecret,
  });
}

function getWarnings() {
  const warnings = [];
  if (settings.mode !== 'builtin') return warnings;

  if (legacyDownloadDir) {
    warnings.push(
      `当前下载目录多了一层 downloads（${legacyDownloadDir}），这是旧版本默认值问题。可在设置中改为上层目录，已有文件仍保留在原位置。`,
    );
  }

  const hasAuthorizedRoot = paths.roots.some((root) => !isPathInside(root, appVar));
  if (!hasAuthorizedRoot) {
    warnings.push(
      '还没有可用的授权目录。请在飞牛「应用设置 → 授权目录」中添加下载目录，应用内即可选择。',
    );
  }
  if (
    settings.downloadDir &&
    !paths.contains(settings.downloadDir)
  ) {
    warnings.push('当前下载目录已不在授权范围内，请在设置中重新选择。');
  }
  if (isPathInside(settings.downloadDir, appVar)) {
    warnings.push(
      '当前下载目录位于应用数据目录，卸载应用时可能被清理。建议改为已授权的共享目录。',
    );
  }
  return warnings;
}

async function saveSettings(patch) {
  const merged = { ...settings, ...patch };
  merged.rpcSecret = settings.rpcSecret;
  if (!Object.prototype.hasOwnProperty.call(patch, 'externalRpcSecret')) {
    merged.externalRpcSecret = settings.externalRpcSecret;
  }

  const next = validateSettings(merged, {
    checkDir: (dir) => paths.contains(dir),
  });

  if (next.mode === 'builtin') {
    next.downloadDir = paths.ensureDirectory(
      next.downloadDir || path.join(appVar, 'downloads'),
    );
  }

  const previous = settings;
  settings = next;
  settingsStore.save(settings);

  if (legacyDownloadDir && next.downloadDir !== legacyDownloadDir) {
    legacyDownloadDir = '';
  }

  let warning = '';
  const needsRestart =
    previous.mode !== next.mode ||
    (next.mode === 'builtin' && previous.rpcPort !== next.rpcPort);

  if (needsRestart) {
    await engine.restart(settings);
  } else if (next.mode === 'builtin') {
    const applied = await engine.applySettings(settings);
    warning = applied.warning || '';
  }

  return {
    settings: publicSettings(settings),
    engine: engine.status(),
    warnings: getWarnings(),
    warning,
  };
}

async function restartEngine() {
  return engine.restart(settings);
}

const snapshots = new SnapshotService({
  getClient,
  getSettings: () => settings,
  getEngineStatus: () => engine.status(),
  getWarnings,
  history,
});

const ctx = {
  appVersion: APP_VERSION,
  paths,
  history,
  engine,
  getSettings: () => settings,
  getPublicSettings: () => publicSettings(settings),
  getClient,
  getEngineStatus: () => engine.status(),
  getWarnings,
  getSnapshot: (options) => snapshots.build(options),
  invalidateSnapshot: () => snapshots.invalidate(),
  saveSettings,
  restartEngine,
  engineLogTail: (lines) => engine.logTail(lines),
};

const server = http.createServer(createRouter(ctx));

server.on('error', (error) => {
  process.stderr.write(`HTTP 服务启动失败：${error.message}\n`);
  process.exit(1);
});

server.listen(listenPort, '0.0.0.0', () => {
  process.stdout.write(
    `AriaPilot fnOS ${APP_VERSION} 正在监听 0.0.0.0:${listenPort}\n`,
  );
});

let shuttingDown = false;

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function startEngineWithRetry(attempt = 0) {
  const status = await engine.start(settings);
  process.stdout.write(
    `aria2 引擎状态：${status.state}${status.port ? `，端口 ${status.port}` : ''}\n`,
  );
  if (status.error) process.stderr.write(`aria2 引擎错误：${status.error}\n`);

  const transient =
    status.state === 'error' &&
    /未响应|都被占用|已退出/.test(status.error || '');

  if (transient && attempt === 0 && !shuttingDown) {
    process.stderr.write('aria2 引擎首次启动失败，3 秒后重试一次\n');
    await delay(3000);
    if (!shuttingDown && engine.state !== 'running') {
      return startEngineWithRetry(1);
    }
  }

  return status;
}

startEngineWithRetry().catch((error) => {
  process.stderr.write(`aria2 引擎启动失败：${error.message}\n`);
});

let trackedAuthMtime = 0;
try {
  trackedAuthMtime = fs.statSync(path.join(appVar, 'auth_paths')).mtimeMs;
} catch {
  trackedAuthMtime = 0;
}

const authWatcher = setInterval(() => {
  const file = path.join(appVar, 'auth_paths');
  try {
    const stat = fs.statSync(file);
    if (stat.mtimeMs !== trackedAuthMtime) {
      trackedAuthMtime = stat.mtimeMs;
      paths.reload();
    }
  } catch {
    /* file removed, keep current roots */
  }
}, 5000);
authWatcher.unref();

async function shutdown(signal) {
  if (shuttingDown) return;
  shuttingDown = true;
  process.stdout.write(`收到 ${signal}，正在退出\n`);
  clearInterval(authWatcher);

  server.close();

  if (engine.state === 'running' || engine.state === 'starting') {
    try {
      await getClient().saveSession();
    } catch {
      /* aria2 may already be unavailable */
    }
  }

  try {
    await engine.stop();
  } catch {
    /* best effort */
  }

  process.exit(0);
}

process.on('SIGTERM', () => {
  shutdown('SIGTERM');
});
process.on('SIGINT', () => {
  shutdown('SIGINT');
});
