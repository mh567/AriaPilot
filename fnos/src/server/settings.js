'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const DEFAULT_SETTINGS = Object.freeze({
  mode: 'builtin',
  downloadDir: '',
  maxConcurrent: 5,
  connectionsPerServer: 5,
  split: 5,
  downloadLimit: '0',
  uploadLimit: '0',
  deleteFilesByDefault: false,
  rpcPort: 6800,
  rpcSecret: '',
  externalRpcUrl: '',
  externalRpcSecret: '',
});

class SettingsError extends Error {
  constructor(message) {
    super(message);
    this.name = 'SettingsError';
  }
}

function makeSecret() {
  return crypto.randomBytes(24).toString('base64url');
}

function normalizeLimit(value) {
  if (value === undefined || value === null) return '0';
  const text = String(value).trim();
  return text === '' ? '0' : text;
}

function isValidSpeedLimit(value) {
  const text = String(value === undefined || value === null ? '' : value).trim();
  if (text === '') return true;
  return /^\d+[KkMm]?$/.test(text);
}

function isLegacyShareDownloadDir(dir, sharePaths = []) {
  if (!dir) return false;
  const resolved = path.resolve(dir);
  return sharePaths.some(
    (share) => resolved === path.resolve(path.join(share, 'downloads')),
  );
}

function resolveLegacyShareDir(dir, sharePaths = []) {
  if (!isLegacyShareDownloadDir(dir, sharePaths)) {
    return { dir, legacy: '' };
  }

  for (const share of sharePaths) {
    const legacy = path.join(share, 'downloads');
    if (path.resolve(dir) !== path.resolve(legacy)) continue;

    try {
      if (fs.readdirSync(legacy).length > 0) {
        return { dir, legacy };
      }
    } catch {
      /* directory missing, safe to fall back to the share root */
    }

    return { dir: share, legacy: '' };
  }

  return { dir, legacy: '' };
}

function normalizeSettings(raw = {}) {
  const source = raw && typeof raw === 'object' ? raw : {};
  const settings = {
    mode: source.mode === 'external' ? 'external' : 'builtin',
    downloadDir:
      typeof source.downloadDir === 'string' ? source.downloadDir.trim() : '',
    maxConcurrent: Number(source.maxConcurrent),
    connectionsPerServer: Number(source.connectionsPerServer),
    split: Number(source.split),
    downloadLimit: normalizeLimit(source.downloadLimit),
    uploadLimit: normalizeLimit(source.uploadLimit),
    deleteFilesByDefault: Boolean(source.deleteFilesByDefault),
    rpcPort: Number(source.rpcPort),
    rpcSecret:
      typeof source.rpcSecret === 'string' ? source.rpcSecret : '',
    externalRpcUrl:
      typeof source.externalRpcUrl === 'string'
        ? source.externalRpcUrl.trim()
        : '',
    externalRpcSecret:
      typeof source.externalRpcSecret === 'string'
        ? source.externalRpcSecret
        : '',
  };

  for (const key of ['maxConcurrent', 'connectionsPerServer', 'split', 'rpcPort']) {
    if (!Number.isFinite(settings[key])) settings[key] = DEFAULT_SETTINGS[key];
  }

  return settings;
}

function validateSettings(input, { checkDir } = {}) {
  const settings = normalizeSettings(input);
  const problems = [];

  if (!Number.isInteger(settings.maxConcurrent) || settings.maxConcurrent < 1 || settings.maxConcurrent > 50) {
    problems.push('并发任务数必须是 1 到 50 之间的整数');
  }
  if (
    !Number.isInteger(settings.connectionsPerServer) ||
    settings.connectionsPerServer < 1 ||
    settings.connectionsPerServer > 64
  ) {
    problems.push('每任务连接数必须是 1 到 64 之间的整数');
  }
  if (!Number.isInteger(settings.split) || settings.split < 1 || settings.split > 64) {
    problems.push('分片数必须是 1 到 64 之间的整数');
  }
  if (!Number.isInteger(settings.rpcPort) || settings.rpcPort < 1024 || settings.rpcPort > 65535) {
    problems.push('aria2 RPC 端口必须是 1024 到 65535 之间的整数');
  }
  if (!isValidSpeedLimit(settings.downloadLimit)) {
    problems.push('下载限速必须是 0，或类似 500K、2M 的数值');
  }
  if (!isValidSpeedLimit(settings.uploadLimit)) {
    problems.push('上传限速必须是 0，或类似 500K、2M 的数值');
  }

  if (settings.mode === 'external') {
    if (!/^https?:\/\//i.test(settings.externalRpcUrl)) {
      problems.push('外部 aria2 地址必须以 http:// 或 https:// 开头');
    }
  }

  if (settings.downloadDir) {
    if (!path.isAbsolute(settings.downloadDir)) {
      problems.push('下载目录必须是绝对路径');
    } else if (/[\r\n]/.test(settings.downloadDir)) {
      problems.push('下载目录不能包含换行符');
    } else if (settings.mode === 'builtin' && checkDir && !checkDir(settings.downloadDir)) {
      problems.push('下载目录不在已授权范围内，请先在应用设置中授权该目录');
    }
  }

  if (problems.length > 0) throw new SettingsError(problems[0]);
  return settings;
}

function publicSettings(settings) {
  const { rpcSecret, externalRpcSecret, ...rest } = settings;
  return {
    ...rest,
    hasExternalSecret: Boolean(externalRpcSecret),
  };
}

class SettingsStore {
  constructor(file) {
    this.file = file;
  }

  load() {
    try {
      const parsed = JSON.parse(fs.readFileSync(this.file, 'utf8'));
      return parsed && typeof parsed === 'object' ? parsed : null;
    } catch {
      return null;
    }
  }

  save(settings) {
    fs.mkdirSync(path.dirname(this.file), { recursive: true });
    const tmp = `${this.file}.${process.pid}.tmp`;
    fs.writeFileSync(tmp, `${JSON.stringify(settings, null, 2)}\n`, {
      mode: 0o600,
    });
    fs.renameSync(tmp, this.file);
  }
}

module.exports = {
  DEFAULT_SETTINGS,
  SettingsError,
  SettingsStore,
  isValidSpeedLimit,
  isLegacyShareDownloadDir,
  makeSecret,
  normalizeLimit,
  normalizeSettings,
  publicSettings,
  resolveLegacyShareDir,
  validateSettings,
};
