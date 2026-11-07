'use strict';

const fs = require('node:fs');
const path = require('node:path');

const FORBIDDEN_ROOTS = ['/proc', '/sys', '/dev', '/run'];

class PathError extends Error {
  constructor(message) {
    super(message);
    this.name = 'PathError';
  }
}

function splitPaths(value) {
  return String(value || '')
    .split(':')
    .map((item) => item.trim())
    .filter(Boolean);
}

function isPathInside(child, parent) {
  const relative = path.relative(parent, child);
  return (
    relative === '' ||
    (relative !== '..' &&
      !relative.startsWith(`..${path.sep}`) &&
      !path.isAbsolute(relative))
  );
}

function isForbiddenRoot(root) {
  if (root === path.parse(root).root) return true;
  return FORBIDDEN_ROOTS.some(
    (forbidden) => root === forbidden || root.startsWith(`${forbidden}${path.sep}`),
  );
}

function resolveRealPath(target) {
  let absolute = path.resolve(target);
  const missing = [];

  for (let depth = 0; depth < 64; depth += 1) {
    try {
      const real = fs.realpathSync(absolute);
      return missing.length > 0
        ? path.join(real, ...missing.slice().reverse())
        : real;
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
      const parent = path.dirname(absolute);
      if (parent === absolute) return path.resolve(target);
      missing.push(path.basename(absolute));
      absolute = parent;
    }
  }

  return path.resolve(target);
}

class AuthorizedPaths {
  constructor({ envPaths = [], sharePaths = [], extraFile = '' } = {}) {
    this.envPaths = envPaths.map((item) => path.resolve(item));
    this.sharePaths = sharePaths.map((item) => path.resolve(item));
    this.extraFile = extraFile;
    this.fallbackRoots = [];
    this.roots = [];
    this.reload();
  }

  addFallback(root) {
    const resolved = resolveRealPath(root);
    if (!this.fallbackRoots.includes(resolved)) this.fallbackRoots.push(resolved);
    this.reload();
  }

  readExtraPaths() {
    if (!this.extraFile) return [];
    try {
      return splitPaths(fs.readFileSync(this.extraFile, 'utf8'));
    } catch {
      return [];
    }
  }

  reload() {
    const candidates = [
      ...this.envPaths,
      ...this.sharePaths,
      ...this.readExtraPaths().map((item) => path.resolve(item)),
      ...this.fallbackRoots,
    ];

    const seen = new Set();
    const roots = [];
    for (const candidate of candidates) {
      let resolved;
      try {
        resolved = resolveRealPath(candidate);
      } catch {
        continue;
      }
      if (!resolved || isForbiddenRoot(resolved) || seen.has(resolved)) continue;
      seen.add(resolved);
      roots.push(resolved);
    }
    this.roots = roots;
  }

  hasRoots() {
    return this.roots.length > 0;
  }

  contains(candidate) {
    if (!candidate) return false;
    let resolved;
    try {
      resolved = resolveRealPath(candidate);
    } catch {
      return false;
    }
    return this.roots.some((root) => isPathInside(resolved, root));
  }

  ensureDirectory(target) {
    if (!target || !path.isAbsolute(target)) {
      throw new PathError('下载目录必须是绝对路径');
    }
    if (/[\r\n]/.test(target)) {
      throw new PathError('下载目录不能包含换行符');
    }
    if (!this.contains(target)) {
      throw new PathError('下载目录不在已授权范围内，请先在应用设置中授权该目录');
    }

    try {
      fs.mkdirSync(target, { recursive: true });
    } catch (error) {
      throw new PathError(`无法创建下载目录：${error.message}`);
    }
    const real = resolveRealPath(target);
    if (!this.contains(real)) {
      throw new PathError('下载目录不在已授权范围内，请先在应用设置中授权该目录');
    }

    const probe = path.join(real, `.ariapilot-write-test-${process.pid}`);
    try {
      fs.writeFileSync(probe, 'ok');
    } catch (error) {
      throw new PathError(`下载目录不可写：${error.message}`);
    } finally {
      try {
        fs.unlinkSync(probe);
      } catch {
        /* probe may not exist */
      }
    }

    return real;
  }

  list(target) {
    const start = target ? path.resolve(target) : this.roots[0];
    if (!start) {
      throw new PathError('应用还没有可用的授权目录，请先在应用设置中授权');
    }
    if (!this.contains(start)) {
      throw new PathError('目录不在已授权范围内');
    }

    const real = resolveRealPath(start);
    let stat;
    try {
      stat = fs.statSync(real);
    } catch {
      throw new PathError('目录不存在');
    }
    if (!stat.isDirectory()) {
      throw new PathError('目标不是目录');
    }

    const entries = [];
    for (const entry of fs.readdirSync(real, { withFileTypes: true })) {
      if (entry.name.startsWith('.')) continue;
      const full = path.join(real, entry.name);
      let isDirectory = entry.isDirectory();
      if (entry.isSymbolicLink()) {
        try {
          isDirectory = fs.statSync(full).isDirectory();
        } catch {
          isDirectory = false;
        }
      }
      if (!isDirectory) continue;
      if (!this.contains(full)) continue;
      entries.push({ name: entry.name, path: full });
    }

    entries.sort((a, b) => a.name.localeCompare(b.name, 'zh-CN'));

    const parentCandidate = path.dirname(real);
    const parent =
      parentCandidate !== real && this.contains(parentCandidate)
        ? parentCandidate
        : null;

    return {
      path: real,
      parent,
      entries: entries.slice(0, 500),
      truncated: entries.length > 500,
    };
  }

  deleteFiles(files = [], taskDir = '') {
    const deleted = [];
    const failed = [];
    const skipped = [];
    const targets = new Set();

    for (const file of files) {
      const raw = file && file.path ? String(file.path) : '';
      if (!raw) continue;
      let full = raw;
      if (!path.isAbsolute(full)) {
        if (!taskDir) {
          skipped.push({ path: raw, reason: '缺少任务目录' });
          continue;
        }
        full = path.join(taskDir, full);
      }
      targets.add(path.resolve(full));
      targets.add(path.resolve(`${full}.aria2`));
    }

    for (const target of targets) {
      let stat;
      try {
        stat = fs.lstatSync(target);
      } catch (error) {
        if (error.code === 'ENOENT') {
          skipped.push({ path: target, reason: '文件已不存在' });
        } else {
          failed.push({ path: target, reason: error.message });
        }
        continue;
      }

      if (stat.isSymbolicLink()) {
        skipped.push({ path: target, reason: '跳过符号链接' });
        continue;
      }

      let real;
      try {
        real = resolveRealPath(target);
      } catch (error) {
        failed.push({ path: target, reason: error.message });
        continue;
      }

      if (!this.contains(real)) {
        failed.push({ path: target, reason: '路径不在授权范围内' });
        continue;
      }

      if (stat.isDirectory()) {
        try {
          fs.rmdirSync(real);
          deleted.push(real);
          this.pruneEmptyDirs(path.dirname(real));
        } catch (error) {
          failed.push({ path: target, reason: error.message });
        }
        continue;
      }

      try {
        fs.unlinkSync(real);
        deleted.push(real);
        this.pruneEmptyDirs(path.dirname(real));
      } catch (error) {
        failed.push({ path: target, reason: error.message });
      }
    }

    return { deleted, failed, skipped };
  }

  pruneEmptyDirs(start) {
    let current = path.resolve(start);
    for (let depth = 0; depth < 24; depth += 1) {
      if (this.roots.includes(current)) break;
      if (!this.contains(current)) break;
      try {
        if (fs.readdirSync(current).length > 0) break;
        fs.rmdirSync(current);
      } catch {
        break;
      }
      const parent = path.dirname(current);
      if (parent === current) break;
      current = parent;
    }
  }
}

module.exports = {
  AuthorizedPaths,
  PathError,
  isPathInside,
  resolveRealPath,
  splitPaths,
};
