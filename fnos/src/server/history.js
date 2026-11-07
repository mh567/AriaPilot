'use strict';

const fs = require('node:fs');
const path = require('node:path');

class HistoryStore {
  constructor(file, { limit = 500 } = {}) {
    this.file = file;
    this.limit = limit;
    this.items = this.load();
  }

  load() {
    try {
      const parsed = JSON.parse(fs.readFileSync(this.file, 'utf8'));
      return Array.isArray(parsed) ? parsed.filter((item) => item && item.gid) : [];
    } catch {
      return [];
    }
  }

  save() {
    try {
      fs.mkdirSync(path.dirname(this.file), { recursive: true });
      const tmp = `${this.file}.${process.pid}.tmp`;
      fs.writeFileSync(tmp, `${JSON.stringify(this.items, null, 2)}\n`, {
        mode: 0o600,
      });
      fs.renameSync(tmp, this.file);
    } catch {
      /* history persistence must never break the API */
    }
  }

  record(tasks = []) {
    const durable = tasks.filter(
      (task) => task && (task.status === 'complete' || task.status === 'error'),
    );
    if (durable.length === 0) return;

    const now = Date.now();
    const map = new Map();
    for (const item of this.items) map.set(item.gid, item);

    let changed = false;
    for (const task of durable) {
      const previous = map.get(task.gid);
      if (
        previous &&
        previous.status === task.status &&
        Number(previous.completedLength) === Number(task.completedLength) &&
        Number(previous.errorCode || 0) === Number(task.errorCode || 0)
      ) {
        continue;
      }

      map.set(task.gid, {
        gid: task.gid,
        status: task.status,
        totalLength: task.totalLength,
        completedLength: task.completedLength,
        errorCode: task.errorCode,
        errorMessage: task.errorMessage,
        dir: task.dir,
        files: task.files,
        bittorrent: task.bittorrent,
        savedAt: previous && previous.savedAt ? previous.savedAt : now,
      });
      changed = true;
    }

    if (!changed) return;

    this.items = Array.from(map.values())
      .sort((a, b) => (b.savedAt || 0) - (a.savedAt || 0))
      .slice(0, this.limit);
    this.save();
  }

  merge(liveStopped = []) {
    const seen = new Set();
    const merged = [];

    for (const task of liveStopped) {
      if (!task || !task.gid || seen.has(task.gid)) continue;
      seen.add(task.gid);
      merged.push(task);
    }

    let extras = 0;
    for (const item of this.items) {
      if (!item || !item.gid || seen.has(item.gid)) continue;
      seen.add(item.gid);
      merged.push(item);
      extras += 1;
    }

    return { items: merged, extras };
  }

  remove(gid) {
    const next = this.items.filter((item) => item.gid !== gid);
    if (next.length === this.items.length) return;
    this.items = next;
    this.save();
  }

  purge() {
    this.items = [];
    this.save();
  }
}

module.exports = { HistoryStore };
