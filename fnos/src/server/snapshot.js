'use strict';

const { normalizeGlobalStat, normalizeTask } = require('./models');

const EMPTY_GLOBAL = {
  downloadSpeed: 0,
  uploadSpeed: 0,
  numActive: 0,
  numWaiting: 0,
  numStopped: 0,
};

class SnapshotService {
  constructor({ getClient, getSettings, getEngineStatus, getWarnings, history }) {
    this.getClient = getClient;
    this.getSettings = getSettings;
    this.getEngineStatus = getEngineStatus;
    this.getWarnings = getWarnings;
    this.history = history;
    this.cache = null;
  }

  invalidate() {
    this.cache = null;
  }

  async build({ loaded = 20 } = {}) {
    const now = Date.now();
    const pageSize = Math.min(500, Math.max(1, loaded));

    if (
      this.cache &&
      this.cache.loaded === pageSize &&
      now - this.cache.at < 400
    ) {
      return this.cache.value;
    }

    const settings = this.getSettings();
    const engine = this.getEngineStatus();
    const warnings = typeof this.getWarnings === 'function' ? this.getWarnings() : [];
    const canDeleteFiles = settings.mode === 'builtin';

    try {
      const client = this.getClient();
      const [global, active, waiting, stopped] = await Promise.all([
        client.getGlobalStat(),
        client.tellActive(),
        client.tellWaiting(0, 100),
        client.tellStopped(-1, pageSize),
      ]);

      const normalizedGlobal = normalizeGlobalStat(global);
      this.history.record(stopped);
      const merged = this.history.merge(stopped);

      const value = {
        engine,
        warnings,
        global: normalizedGlobal,
        active: active.map((task) => normalizeTask(task, { canDeleteFiles })),
        waiting: waiting.map((task) => normalizeTask(task, { canDeleteFiles })),
        stopped: merged.items.map((task) =>
          normalizeTask(task, { canDeleteFiles }),
        ),
        stoppedTotal: Math.max(
          normalizedGlobal.numStopped,
          merged.items.length,
        ),
        hasMoreStopped: stopped.length < normalizedGlobal.numStopped,
        serverTime: now,
      };

      this.cache = { loaded: pageSize, at: now, value };
      return value;
    } catch (error) {
      const message =
        engine.state === 'starting' ? '' : engine.error || error.message;
      const value = {
        engine: { ...engine, error: message },
        warnings,
        global: { ...EMPTY_GLOBAL },
        active: [],
        waiting: [],
        stopped: [],
        stoppedTotal: 0,
        hasMoreStopped: false,
        serverTime: now,
      };
      this.cache = { loaded: pageSize, at: now, value };
      return value;
    }
  }
}

module.exports = { SnapshotService };
