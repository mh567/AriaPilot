'use strict';

const TASK_KEYS = [
  'gid',
  'status',
  'totalLength',
  'completedLength',
  'downloadSpeed',
  'uploadSpeed',
  'connections',
  'numSeeders',
  'seeder',
  'errorCode',
  'errorMessage',
  'dir',
  'files',
  'bittorrent',
  'belongsTo',
  'followedBy',
];

class Aria2Error extends Error {
  constructor(code, message, { httpStatus = 0 } = {}) {
    super(message);
    this.name = 'Aria2Error';
    this.code = code;
    this.httpStatus = httpStatus;
  }
}

class Aria2Client {
  constructor({ url, secret = '', timeoutMs = 5000 }) {
    this.url = url;
    this.secret = secret || '';
    this.timeoutMs = timeoutMs;
    this.seq = 0;
  }

  async call(method, params = []) {
    const id = String(++this.seq);
    const requestParams = this.secret ? [`token:${this.secret}`, ...params] : params;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);

    try {
      const response = await fetch(this.url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          jsonrpc: '2.0',
          id,
          method,
          params: requestParams,
        }),
        signal: controller.signal,
      });

      if (!response.ok) {
        throw new Aria2Error(-1, `aria2 RPC 返回 HTTP ${response.status}`, {
          httpStatus: response.status,
        });
      }

      let payload;
      try {
        payload = await response.json();
      } catch {
        throw new Aria2Error(-1, 'aria2 RPC 返回了无法解析的响应');
      }

      if (payload && payload.error) {
        throw new Aria2Error(
          payload.error.code,
          payload.error.message || 'aria2 RPC 调用失败',
        );
      }

      return payload ? payload.result : undefined;
    } catch (error) {
      if (error instanceof Aria2Error) throw error;
      if (error.name === 'AbortError') {
        throw new Aria2Error(-2, '连接 aria2 超时');
      }
      throw new Aria2Error(-3, `连接 aria2 失败：${error.message}`);
    } finally {
      clearTimeout(timer);
    }
  }

  getVersion() {
    return this.call('aria2.getVersion');
  }

  getGlobalStat() {
    return this.call('aria2.getGlobalStat');
  }

  getGlobalOption() {
    return this.call('aria2.getGlobalOption');
  }

  tellStatus(gid, keys = TASK_KEYS) {
    return this.call('aria2.tellStatus', [gid, keys]);
  }

  tellActive(keys = TASK_KEYS) {
    return this.call('aria2.tellActive', [keys]);
  }

  tellWaiting(offset, num, keys = TASK_KEYS) {
    return this.call('aria2.tellWaiting', [offset, num, keys]);
  }

  tellStopped(offset, num, keys = TASK_KEYS) {
    return this.call('aria2.tellStopped', [offset, num, keys]);
  }

  addUri(uris, options = {}) {
    return this.call('aria2.addUri', [uris, options]);
  }

  addTorrent(torrentBase64, options = {}) {
    return this.call('aria2.addTorrent', [torrentBase64, [], options]);
  }

  pause(gid) {
    return this.call('aria2.pause', [gid]);
  }

  unpause(gid) {
    return this.call('aria2.unpause', [gid]);
  }

  remove(gid) {
    return this.call('aria2.remove', [gid]);
  }

  removeDownloadResult(gid) {
    return this.call('aria2.removeDownloadResult', [gid]);
  }

  purgeDownloadResult() {
    return this.call('aria2.purgeDownloadResult');
  }

  changeGlobalOption(options) {
    return this.call('aria2.changeGlobalOption', [options]);
  }

  saveSession() {
    return this.call('aria2.saveSession');
  }
}

module.exports = { Aria2Client, Aria2Error, TASK_KEYS };
