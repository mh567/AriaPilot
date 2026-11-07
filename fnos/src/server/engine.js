'use strict';

const fs = require('node:fs');
const net = require('node:net');
const path = require('node:path');
const { spawn } = require('node:child_process');
const { Aria2Client } = require('./aria2');

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function canBind(port) {
  return new Promise((resolve) => {
    const server = net.createServer();
    server.unref();
    server.once('error', () => resolve(false));
    server.once('listening', () => {
      server.close(() => resolve(true));
    });
    server.listen(port, '127.0.0.1');
  });
}

function isAlive(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

class Engine {
  constructor({ binPath, confPath, dataDir, logDir }) {
    this.binPath = binPath;
    this.confPath = confPath;
    this.dataDir = dataDir;
    this.logDir = logDir;
    this.logPath = path.join(logDir, 'aria2.log');
    this.sessionPath = path.join(dataDir, 'aria2.session');
    this.pidPath = path.join(dataDir, 'aria2.pid');

    this.child = null;
    this.port = 0;
    this.version = '';
    this.state = 'stopped';
    this.error = '';
    this.stopping = false;
    this.settings = null;
    this.operation = Promise.resolve();
  }

  enqueue(task) {
    const result = this.operation.then(task, task);
    this.operation = result.then(
      () => {},
      () => {},
    );
    return result;
  }

  start(settings) {
    return this.enqueue(() => this.startInternal(settings));
  }

  stop() {
    return this.enqueue(() => this.stopInternal());
  }

  restart(settings) {
    return this.enqueue(async () => {
      await this.stopInternal();
      return this.startInternal(settings);
    });
  }

  applySettings(settings) {
    return this.enqueue(() => this.applySettingsInternal(settings));
  }

  status() {
    return {
      state: this.state,
      port: this.port,
      version: this.version,
      error: this.error,
      logPath: this.logPath,
      mode: this.settings ? this.settings.mode : 'builtin',
    };
  }

  client(settings = this.settings) {
    if (!settings) return null;
    if (settings.mode === 'external') {
      return new Aria2Client({
        url: settings.externalRpcUrl,
        secret: settings.externalRpcSecret,
      });
    }
    return new Aria2Client({
      url: `http://127.0.0.1:${this.port || settings.rpcPort}/jsonrpc`,
      secret: settings.rpcSecret,
    });
  }

  async startInternal(settings) {
    this.settings = settings;
    this.error = '';

    if (settings.mode !== 'builtin') {
      this.state = 'external';
      this.port = 0;
      return this.status();
    }

    if (this.child && this.state === 'running') return this.status();

    if (!fs.existsSync(this.binPath)) {
      this.state = 'missing';
      this.error = `未找到内置 aria2c：${this.binPath}`;
      return this.status();
    }

    fs.mkdirSync(this.dataDir, { recursive: true });
    fs.mkdirSync(this.logDir, { recursive: true });
    if (!fs.existsSync(this.sessionPath)) {
      fs.writeFileSync(this.sessionPath, '');
    }
    this.rotateLog();

    this.state = 'starting';

    try {
      const picked = await this.pickPort(settings);
      this.port = picked.port;
      this.writeConfig(settings, picked.port);

      this.spawnProcess();
      await this.waitReady(settings.rpcSecret);
      this.state = 'running';
      return this.status();
    } catch (error) {
      this.state = 'error';
      this.error = error.message;
      await this.stopProcess();
      return this.status();
    }
  }

  async pickPort(settings) {
    const preferred = Number(settings.rpcPort) || 6800;

    for (let offset = 0; offset <= 10; offset += 1) {
      const port = preferred + offset;
      if (port > 65535) break;

      // An existing RPC service may run in a container with different paths and permissions.
      if (await canBind(port)) return { port };
    }

    throw new Error(`aria2 RPC 端口 ${preferred} 到 ${preferred + 10} 都被占用`);
  }

  writeConfig(settings, port) {
    const lines = [
      'daemon=false',
      'console-log-level=notice',
      'enable-rpc=true',
      'rpc-listen-all=false',
      `rpc-listen-port=${port}`,
      `rpc-secret=${settings.rpcSecret}`,
      `dir=${settings.downloadDir}`,
      'continue=true',
      'auto-file-renaming=true',
      'allow-overwrite=false',
      'content-disposition-default-utf8=true',
      `save-session=${this.sessionPath}`,
      `input-file=${this.sessionPath}`,
      'save-session-interval=30',
      'file-allocation=none',
      `max-concurrent-downloads=${settings.maxConcurrent}`,
      `max-overall-download-limit=${settings.downloadLimit}`,
      `max-overall-upload-limit=${settings.uploadLimit}`,
      `log=${this.logPath}`,
      'log-level=warn',
      'bt-save-metadata=true',
      'follow-torrent=true',
    ];

    fs.mkdirSync(path.dirname(this.confPath), { recursive: true });
    fs.writeFileSync(this.confPath, `${lines.join('\n')}\n`, { mode: 0o600 });
  }

  spawnProcess() {
    const outPath = path.join(this.logDir, 'aria2.out.log');
    const errPath = path.join(this.logDir, 'aria2.err.log');
    const out = fs.openSync(outPath, 'a');
    const err = fs.openSync(errPath, 'a');

    try {
      this.child = spawn(
        this.binPath,
        ['--conf-path', this.confPath, `--stop-with-process=${process.pid}`],
        {
          stdio: ['ignore', out, err],
          // fnOS's inherited HOME can make the bundled static aria2 crash at startup.
          env: { ...process.env, HOME: this.dataDir },
        },
      );
    } finally {
      fs.closeSync(out);
      fs.closeSync(err);
    }

    this.child.once('error', (error) => {
      this.child = null;
      this.state = 'error';
      this.error = `aria2 无法启动：${error.message}`;
    });

    if (this.child.pid) {
      fs.writeFileSync(this.pidPath, String(this.child.pid), { mode: 0o600 });
    }

    this.child.once('exit', (code, signal) => {
      this.child = null;
      if (this.stopping) return;
      if (this.state === 'starting' || this.state === 'running') {
        this.state = 'error';
        this.error = `aria2 已退出（code=${code}, signal=${signal}）`;
      }
    });
  }

  async waitReady(secret) {
    const client = new Aria2Client({
      url: `http://127.0.0.1:${this.port}/jsonrpc`,
      secret,
      timeoutMs: 1000,
    });

    let lastError = '';
    for (let attempt = 0; attempt < 20; attempt += 1) {
      if (this.state === 'error') {
        throw new Error(this.startupError(this.error));
      }
      try {
        const version = await client.getVersion();
        if (this.state === 'error') break;
        this.version = (version && version.version) || '';
        return;
      } catch (error) {
        lastError = error.message;
        await delay(250);
      }
    }

    const reason = this.state === 'error'
      ? this.error
      : `aria2 启动后未响应（端口 ${this.port}）：${lastError}`;
    throw new Error(this.startupError(reason));
  }

  startupError(reason) {
    const output = [this.logPath,
      path.join(this.logDir, 'aria2.out.log'),
      path.join(this.logDir, 'aria2.err.log')]
      .map((file) => this.logTail(8, file)).filter(Boolean).join('\n');
    const message = output ? `${reason}\n${output}` : reason;
    return this.settings && this.settings.rpcSecret
      ? message.replaceAll(this.settings.rpcSecret, '<REDACTED>') : message;
  }

  async applySettingsInternal(settings) {
    this.settings = settings;
    if (settings.mode !== 'builtin') {
      return { warning: '' };
    }
    if (this.state !== 'running' || !this.port) {
      return {
        warning: this.error
          ? `内置 aria2 未就绪：${this.error}`
          : '内置 aria2 尚未就绪，设置已保存，将在引擎启动后生效',
      };
    }

    const client = this.client(settings);
    try {
      await client.changeGlobalOption({
        dir: settings.downloadDir,
        'max-concurrent-downloads': String(settings.maxConcurrent),
        'max-overall-download-limit': settings.downloadLimit,
        'max-overall-upload-limit': settings.uploadLimit,
      });
      await client.saveSession();
      return { warning: '' };
    } catch (error) {
      return { warning: `设置已保存，但应用到 aria2 失败：${error.message}` };
    }
  }

  async stopInternal() {
    if (this.state === 'external' || this.state === 'stopped') {
      return this.status();
    }
    this.stopping = true;
    await this.stopProcess();
    this.stopping = false;
    this.state = 'stopped';
    this.port = 0;
    this.error = '';
    return this.status();
  }

  async stopProcess() {
    const pid = this.child ? this.child.pid : this.readPid();
    if (pid > 0 && this.pidLooksLikeAria2(pid)) {
      try {
        process.kill(pid, 'SIGTERM');
      } catch {
        /* already gone */
      }

      for (let attempt = 0; attempt < 50 && isAlive(pid); attempt += 1) {
        await delay(200);
      }

      if (isAlive(pid)) {
        try {
          process.kill(pid, 'SIGKILL');
        } catch {
          /* already gone */
        }
      }
    }

    try {
      fs.unlinkSync(this.pidPath);
    } catch {
      /* no pid file */
    }
    this.child = null;
  }

  pidLooksLikeAria2(pid) {
    try {
      const command = fs
        .readFileSync(`/proc/${pid}/cmdline`, 'utf8')
        .replace(/\0/g, ' ');
      return command.includes('aria2');
    } catch {
      return true;
    }
  }

  readPid() {
    try {
      const value = Number(fs.readFileSync(this.pidPath, 'utf8').trim());
      return Number.isInteger(value) && value > 0 ? value : 0;
    } catch {
      return 0;
    }
  }

  rotateLog() {
    try {
      const stat = fs.statSync(this.logPath);
      if (stat.size > 5 * 1024 * 1024) {
        const rotated = `${this.logPath}.1`;
        try {
          fs.unlinkSync(rotated);
        } catch {
          /* no previous rotation */
        }
        fs.renameSync(this.logPath, rotated);
      }
    } catch {
      /* log does not exist yet */
    }
  }

  logTail(lines = 20, file = this.logPath) {
    try {
      const stat = fs.statSync(file);
      const start = Math.max(0, stat.size - 8192);
      const buffer = Buffer.alloc(stat.size - start);
      const fd = fs.openSync(file, 'r');
      try {
        fs.readSync(fd, buffer, 0, buffer.length, start);
      } finally {
        fs.closeSync(fd);
      }
      return buffer
        .toString('utf8')
        .split('\n')
        .filter(Boolean)
        .slice(-lines)
        .join('\n');
    } catch {
      return '';
    }
  }
}

module.exports = { Engine, canBind };
