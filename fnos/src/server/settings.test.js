'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const {
  DEFAULT_SETTINGS,
  isValidSpeedLimit,
  isLegacyShareDownloadDir,
  makeSecret,
  normalizeSettings,
  publicSettings,
  resolveLegacyShareDir,
  validateSettings,
} = require('./settings');

test('isValidSpeedLimit accepts aria2 style limits', () => {
  for (const value of ['0', '500K', '500k', '2M', '2m', '128', '']) {
    assert.equal(isValidSpeedLimit(value), true, value);
  }
  for (const value of ['-1', '2G', 'abc', '1.5M', '500 K']) {
    assert.equal(isValidSpeedLimit(value), false, value);
  }
});

test('normalizeSettings fills defaults and coerces limits', () => {
  const settings = normalizeSettings({ downloadLimit: '', uploadLimit: ' 2M ' });
  assert.equal(settings.mode, 'builtin');
  assert.equal(settings.maxConcurrent, DEFAULT_SETTINGS.maxConcurrent);
  assert.equal(settings.downloadLimit, '0');
  assert.equal(settings.uploadLimit, '2M');
  assert.equal(settings.deleteFilesByDefault, false);
});

test('validateSettings rejects out of range values', () => {
  assert.throws(() => validateSettings({ maxConcurrent: 0 }), /并发任务数/);
  assert.throws(() => validateSettings({ connectionsPerServer: 65 }), /每任务连接数/);
  assert.throws(() => validateSettings({ split: 0 }), /分片数/);
  assert.throws(() => validateSettings({ rpcPort: 80 }), /RPC 端口/);
  assert.throws(() => validateSettings({ downloadLimit: '2G' }), /下载限速/);
});

test('validateSettings checks the download directory through callback', () => {
  assert.throws(
    () =>
      validateSettings(
        { downloadDir: '/vol1/downloads' },
        { checkDir: () => false },
      ),
    /授权/,
  );

  const settings = validateSettings(
    { downloadDir: '/vol1/downloads' },
    { checkDir: () => true },
  );
  assert.equal(settings.downloadDir, '/vol1/downloads');
});

test('validateSettings requires http url in external mode', () => {
  assert.throws(
    () => validateSettings({ mode: 'external', externalRpcUrl: 'localhost:6800' }),
    /http/,
  );
  assert.doesNotThrow(() =>
    validateSettings({
      mode: 'external',
      externalRpcUrl: 'http://127.0.0.1:6800/jsonrpc',
      downloadDir: '/remote/path',
    }),
  );
});

test('publicSettings hides secrets', () => {
  const view = publicSettings({
    ...DEFAULT_SETTINGS,
    rpcSecret: 'local-secret',
    externalRpcSecret: 'remote-secret',
  });
  assert.equal(view.rpcSecret, undefined);
  assert.equal(view.externalRpcSecret, undefined);
  assert.equal(view.hasExternalSecret, true);
});

test('isLegacyShareDownloadDir detects the duplicated downloads path', () => {
  const shares = ['/vol1/@appshare/ariapilot/downloads'];
  assert.equal(
    isLegacyShareDownloadDir(
      '/vol1/@appshare/ariapilot/downloads/downloads',
      shares,
    ),
    true,
  );
  assert.equal(
    isLegacyShareDownloadDir('/vol1/@appshare/ariapilot/downloads', shares),
    false,
  );
  assert.equal(isLegacyShareDownloadDir('/vol1/downloads', shares), false);
});

test('resolveLegacyShareDir migrates only when the legacy folder is empty', () => {
  const base = fs.mkdtempSync(path.join(os.tmpdir(), 'ariapilot-legacy-'));
  const share = path.join(base, 'appshare', 'ariapilot', 'downloads');
  const legacy = path.join(share, 'downloads');
  fs.mkdirSync(legacy, { recursive: true });

  let result = resolveLegacyShareDir(legacy, [share]);
  assert.equal(result.dir, share);
  assert.equal(result.legacy, '');

  fs.writeFileSync(path.join(legacy, 'file.bin'), 'x');
  result = resolveLegacyShareDir(legacy, [share]);
  assert.equal(result.dir, legacy);
  assert.equal(result.legacy, legacy);

  fs.rmSync(base, { recursive: true, force: true });
});

test('makeSecret produces a 32 character url safe token', () => {
  const secret = makeSecret();
  assert.equal(secret.length, 32);
  assert.match(secret, /^[A-Za-z0-9_-]+$/);
  assert.notEqual(secret, makeSecret());
});
