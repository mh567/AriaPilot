'use strict';

const ICONS = {
  download:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 3v12"/><path d="m7 10 5 5 5-5"/><path d="M4 17v2a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-2"/></svg>',
  check:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="m8.5 12 2.5 2.5 4.5-5"/></svg>',
  settings:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.9.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.9 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.9l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.9.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.9-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.9V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1Z"/></svg>',
  plus:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg>',
  refresh:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 11a8 8 0 1 0-2.3 6.3"/><path d="M20 4v7h-7"/></svg>',
  x:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="m6 6 12 12M18 6 6 18"/></svg>',
  pause:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M9 5v14M15 5v14"/></svg>',
  play:
    '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M8 5.5v13a1 1 0 0 0 1.5.9l10-6.5a1 1 0 0 0 0-1.8l-10-6.5A1 1 0 0 0 8 5.5Z"/></svg>',
  trash:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 7h16"/><path d="M10 11v6M14 11v6"/><path d="M6 7l1 13h10l1-13"/><path d="M9 7V4h6v3"/></svg>',
  folder:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2Z"/></svg>',
  up:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 19V5"/><path d="m6 11 6-6 6 6"/></svg>',
  file:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8Z"/><path d="M14 3v5h5"/></svg>',
  magnet:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 4v8a6 6 0 0 0 12 0V4"/><path d="M6 4h4v8M14 4h4v8"/><path d="M6 8h4M14 8h4"/></svg>',
  alert:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 3 2.8 20h18.4L12 3Z"/><path d="M12 9v5M12 17.5v.1"/></svg>',
  inbox:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 13h5l1.5 3h5L16 13h5"/><path d="M5.5 5h13L21 13v5a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-5L5.5 5Z"/></svg>',
};

const state = {
  view: 'active',
  snapshot: null,
  stoppedLoaded: 20,
  settings: null,
  roots: [],
  engineMode: 'builtin',
  stream: null,
  pollingTimer: null,
  streamFailures: 0,
  browse: { target: 'add', path: '', parent: null },
  pendingDelete: null,
  torrent: null,
};

const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));

function escapeHtml(value) {
  return String(value === undefined || value === null ? '' : value).replace(
    /[&<>"']/g,
    (char) =>
      ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]),
  );
}

function icon(name) {
  return ICONS[name] || '';
}

function hydrateIcons(root = document) {
  $$('[data-icon]', root).forEach((element) => {
    const name = element.getAttribute('data-icon');
    if (ICONS[name]) element.innerHTML = ICONS[name];
  });
}

function fmtBytes(bytes) {
  const value = Number(bytes) || 0;
  if (value <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  const index = Math.min(
    units.length - 1,
    Math.floor(Math.log(value) / Math.log(1024)),
  );
  const scaled = value / Math.pow(1024, index);
  const rounded = scaled >= 100 || index === 0 ? Math.round(scaled) : scaled.toFixed(1);
  return `${rounded} ${units[index]}`;
}

function fmtSpeed(bytesPerSecond) {
  return `${fmtBytes(bytesPerSecond)}/s`;
}

function fmtEta(seconds) {
  if (seconds === null || seconds === undefined || !Number.isFinite(seconds)) {
    return '--';
  }
  if (seconds < 60) return `${Math.max(1, Math.round(seconds))} 秒`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes} 分 ${Math.round(seconds % 60)} 秒`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours} 小时 ${minutes % 60} 分`;
  return `${Math.floor(hours / 24)} 天 ${hours % 24} 小时`;
}

async function api(path, options = {}) {
  const response = await fetch(path, {
    cache: 'no-store',
    headers: { 'Content-Type': 'application/json' },
    ...options,
  });

  let data = null;
  try {
    data = await response.json();
  } catch {
    data = null;
  }

  if (!response.ok) {
    const message =
      data && data.error && data.error.message
        ? data.error.message
        : `请求失败（${response.status}）`;
    throw new Error(message);
  }

  return data;
}

function toast(message, type = 'info', timeout = 4200) {
  const element = document.createElement('div');
  element.className = `toast${
    type === 'error' ? ' is-error' : type === 'success' ? ' is-success' : ''
  }`;
  element.textContent = message;
  $('#toasts').appendChild(element);

  setTimeout(() => {
    element.style.opacity = '0';
    element.style.transform = 'translateY(4px)';
    setTimeout(() => element.remove(), 220);
  }, timeout);
}

function openModal(id) {
  $(`#${id}`).classList.remove('hidden');
  document.body.style.overflow = 'hidden';
}

function closeModal(id) {
  $(`#${id}`).classList.add('hidden');
  if ($$('.modal:not(.hidden)').length === 0) {
    document.body.style.overflow = '';
  }
}

function setButtonBusy(button, busy) {
  if (!button) return;
  button.disabled = busy;
}

function switchView(view) {
  state.view = view;
  $$('[data-view]').forEach((button) => {
    button.classList.toggle('is-active', button.dataset.view === view);
  });
  $$('.view').forEach((section) => {
    section.classList.toggle('hidden', section.id !== `view-${view}`);
  });

  if (view === 'settings') {
    loadSettings().catch((error) => toast(error.message, 'error'));
  }
  if (view === 'stopped' && state.stoppedLoaded > 20) {
    loadStopped(state.stoppedLoaded).catch((error) => toast(error.message, 'error'));
  }
}

function connectStream() {
  if (state.stream) {
    state.stream.close();
    state.stream = null;
  }

  const source = new EventSource('/api/events');
  state.stream = source;

  source.addEventListener('open', () => {
    state.streamFailures = 0;
    stopPolling();
  });

  source.addEventListener('snapshot', (event) => {
    state.streamFailures = 0;
    stopPolling();
    try {
      applySnapshot(JSON.parse(event.data));
    } catch {
      /* ignore malformed frame */
    }
  });

  source.addEventListener('error', () => {
    source.close();
    if (state.stream === source) state.stream = null;
    state.streamFailures += 1;
    if (state.streamFailures >= 2) startPolling();
    setTimeout(connectStream, 4000);
  });
}

function startPolling() {
  if (state.pollingTimer) return;
  state.pollingTimer = setInterval(() => {
    fetchSnapshot().catch(() => {});
  }, 2000);
}

function stopPolling() {
  if (!state.pollingTimer) return;
  clearInterval(state.pollingTimer);
  state.pollingTimer = null;
}

async function fetchSnapshot() {
  const snapshot = await api(`/api/snapshot?loaded=${state.stoppedLoaded}`);
  applySnapshot(snapshot);
}

function applySnapshot(snapshot) {
  if (state.stoppedLoaded > 20 && state.snapshot) {
    snapshot.stopped = state.snapshot.stopped;
    snapshot.stoppedTotal = state.snapshot.stoppedTotal;
    snapshot.hasMoreStopped = state.snapshot.hasMoreStopped;
  }
  state.snapshot = snapshot;
  render();
}

function findTask(gid) {
  if (!state.snapshot) return null;
  return [
    ...(state.snapshot.active || []),
    ...(state.snapshot.waiting || []),
    ...(state.snapshot.stopped || []),
  ].find((task) => task.gid === gid);
}

function render() {
  const snapshot = state.snapshot;
  if (!snapshot) return;

  const global = snapshot.global || {};
  const active = snapshot.active || [];
  const waiting = snapshot.waiting || [];
  const stopped = snapshot.stopped || [];
  const running = active.length + waiting.length;

  $('#dlSpeed').textContent = fmtSpeed(global.downloadSpeed);
  $('#ulSpeed').textContent = fmtSpeed(global.uploadSpeed);
  $('#activeCount').textContent = String(global.numActive || 0);
  $('#waitingCount').textContent = String(global.numWaiting || 0);
  $('#navActiveCount').textContent = String(running);
  $('#navStoppedCount').textContent = String(snapshot.stoppedTotal || 0);

  $('#activeSummary').textContent =
    running === 0
      ? '当前没有进行中的任务'
      : `${running} 个任务，总下载速度 ${fmtSpeed(global.downloadSpeed)}`;

  $('#stoppedSummary').textContent =
    (snapshot.stoppedTotal || 0) === 0
      ? '完成的下载会保留在这里'
      : `共 ${snapshot.stoppedTotal} 条记录`;

  renderEngine(snapshot.engine || {});
  renderWarnings(snapshot.warnings || []);
  renderTaskList($('#activeList'), [...active, ...waiting], 'active');
  renderTaskList($('#stoppedList'), stopped, 'stopped');

  $('#loadMoreWrap').classList.toggle(
    'hidden',
    state.view !== 'stopped' || !snapshot.hasMoreStopped,
  );
}

function renderEngine(engine) {
  const dot = $('#engineDot');
  const states = {
    running: '运行中',
    starting: '启动中',
    stopped: '已停止',
    error: '引擎异常',
    missing: '缺少引擎',
    external: '外部 aria2',
  };

  const hasError = Boolean(engine.error);
  const level = hasError
    ? 'is-error'
    : engine.state === 'running'
      ? 'is-running'
      : engine.state === 'starting'
        ? 'is-starting'
        : engine.state === 'error' || engine.state === 'missing'
          ? 'is-error'
          : '';

  dot.className = `dot ${level}`.trim();
  $('#engineText').textContent = hasError
    ? '引擎异常'
    : states[engine.state] || '未知';

  if (hasError) {
    $('#engineMeta').textContent = engine.error;
  } else if (engine.state === 'running') {
    $('#engineMeta').textContent = `aria2 ${engine.version || ''} · 端口 ${engine.port}`;
  } else if (engine.state === 'external') {
    $('#engineMeta').textContent = '连接到已有 aria2 服务';
  } else {
    $('#engineMeta').textContent = '暂无';
  }

  const detail = $('#engineDetail');
  if (detail) {
    if (hasError) {
      detail.textContent = engine.error;
    } else if (engine.state === 'running') {
      detail.textContent = `aria2 ${engine.version || ''}，监听 127.0.0.1:${engine.port}`;
    } else if (engine.state === 'external') {
      detail.textContent = '当前使用外部 aria2，文件删除与目录浏览已禁用';
    } else {
      detail.textContent = '引擎未运行';
    }
  }
}

function renderWarnings(warnings) {
  const bar = $('#warningBar');
  if (!warnings || warnings.length === 0) {
    bar.classList.add('hidden');
    bar.innerHTML = '';
    return;
  }
  bar.classList.remove('hidden');
  bar.innerHTML = `<ul>${warnings
    .map((warning) => `<li>${escapeHtml(warning)}</li>`)
    .join('')}</ul>`;
}

function statusClass(task) {
  if (task.isError) return 'is-error';
  if (task.isComplete) return 'is-complete';
  if (task.isPaused) return 'is-paused';
  return 'is-active';
}

function taskRow(task) {
  const status = statusClass(task);
  const percent = Math.max(
    0,
    Math.min(100, Math.round((Number(task.progress) || 0) * 100)),
  );
  const kind = task.isTorrent ? 'magnet' : 'file';
  const isActive = task.isActive;
  const canResume = task.status === 'paused' || task.status === 'waiting';

  const meta = task.isError && task.errorMessage
    ? `<div class="task-meta is-error" title="${escapeHtml(task.errorMessage)}">${escapeHtml(task.errorMessage)}</div>`
    : `<div class="task-meta" title="${escapeHtml(task.dir)}">${escapeHtml(task.dir || '')}</div>`;

  const footParts = [];
  if (task.totalLength > 0) {
    footParts.push(
      `<span class="strong">${fmtBytes(task.completedLength)}</span> / ${fmtBytes(task.totalLength)}`,
    );
  } else {
    footParts.push(`<span class="strong">${fmtBytes(task.completedLength)}</span>`);
  }
  if (isActive) {
    footParts.push(`<span>${fmtSpeed(task.downloadSpeed)}</span>`);
    footParts.push(`<span>剩余 ${fmtEta(task.eta)}</span>`);
    if (task.connections > 0) footParts.push(`<span>${task.connections} 连接</span>`);
  } else if (task.isComplete) {
    footParts.push('<span>已完成</span>');
    if (task.fileCount > 0) footParts.push(`<span>${task.fileCount} 个文件</span>`);
  } else if (task.isError) {
    footParts.push('<span>下载失败</span>');
  } else {
    footParts.push(`<span>${escapeHtml(task.statusLabel)}</span>`);
  }
  if (task.uploadSpeed > 0) footParts.push(`<span>上传 ${fmtSpeed(task.uploadSpeed)}</span>`);

  let actions = '';
  if (isActive) {
    actions += `<button class="button ghost" type="button" data-action="pause" data-gid="${escapeHtml(task.gid)}" title="暂停" aria-label="暂停">${icon('pause')}</button>`;
  } else if (canResume) {
    actions += `<button class="button ghost" type="button" data-action="resume" data-gid="${escapeHtml(task.gid)}" title="继续" aria-label="继续">${icon('play')}</button>`;
  }
  actions += `<button class="button ghost" type="button" data-action="delete" data-gid="${escapeHtml(task.gid)}" title="删除" aria-label="删除">${icon('trash')}</button>`;

  return `
    <article class="task ${status}">
      <div class="task-kind">${icon(task.isError ? 'alert' : kind)}</div>
      <div class="task-body">
        <div class="task-top">
          <span class="task-name" title="${escapeHtml(task.name)}">${escapeHtml(task.name)}</span>
          <span class="chip ${status}">${escapeHtml(task.statusLabel)}</span>
        </div>
        ${meta}
        <div class="progress"><span style="width:${percent}%"></span></div>
        <div class="task-foot">${footParts.join('')}</div>
      </div>
      <div class="task-actions">${actions}</div>
    </article>
  `;
}

function renderTaskList(container, tasks, tab) {
  if (!tasks || tasks.length === 0) {
    container.innerHTML =
      tab === 'stopped'
        ? `<div class="empty">${icon('check')}<strong>还没有已完成的任务</strong><span>完成或失败的任务会显示在这里</span></div>`
        : `<div class="empty">${icon('inbox')}<strong>当前没有下载任务</strong><span>点击「新建下载」添加 HTTP、磁力或种子任务</span></div>`;
    return;
  }
  container.innerHTML = tasks.map((task) => taskRow(task)).join('');
}

async function loadStopped(loaded) {
  const data = await api(`/api/tasks?tab=stopped&loaded=${loaded}`);
  state.stoppedLoaded = loaded;
  if (!state.snapshot) state.snapshot = {};
  state.snapshot.stopped = data.stopped || [];
  state.snapshot.stoppedTotal = data.stoppedTotal || 0;
  state.snapshot.hasMoreStopped = Boolean(data.hasMoreStopped);
  render();
}

async function loadSettings() {
  const data = await api('/api/settings');
  state.settings = data.settings;
  state.roots = data.roots || [];
  state.engineMode = data.settings.mode || 'builtin';

  $('#settingDir').value = data.settings.downloadDir || '';
  $('#settingConcurrent').value = data.settings.maxConcurrent;
  $('#settingConnections').value = data.settings.connectionsPerServer;
  $('#settingSplit').value = data.settings.split;
  $('#settingDownloadLimit').value = data.settings.downloadLimit;
  $('#settingUploadLimit').value = data.settings.uploadLimit;
  $('#settingPort').value = data.settings.rpcPort;
  $('#settingExternalUrl').value = data.settings.externalRpcUrl || '';
  $('#settingExternalSecret').value = '';
  $('#settingExternalSecret').placeholder = data.settings.hasExternalSecret
    ? '已设置，留空表示不修改'
    : '未设置';
  $('#settingDeleteFiles').checked = Boolean(data.settings.deleteFilesByDefault);

  setMode(state.engineMode);
  renderRoots();
  renderEngine(state.snapshot ? state.snapshot.engine || {} : {});
}

function renderRoots() {
  const list = $('#rootsList');
  if (!state.roots || state.roots.length === 0) {
    list.innerHTML = '<span class="hint">暂无授权目录，请先在飞牛应用设置中授权。</span>';
    return;
  }
  list.innerHTML = state.roots
    .map(
      (root) =>
        `<button type="button" class="root-chip" data-root="${escapeHtml(root)}" title="${escapeHtml(root)}">${escapeHtml(root)}</button>`,
    )
    .join('');
}

function setMode(mode) {
  state.engineMode = mode;
  $$('.segment').forEach((button) => {
    button.classList.toggle('is-active', button.dataset.mode === mode);
  });

  const builtin = mode === 'builtin';
  $('#builtinPanel').classList.toggle('hidden', !builtin);
  $('#externalPanel').classList.toggle('hidden', builtin);
  $('#browseSettingDir').classList.toggle('hidden', !builtin);
  $('#settingDir').readOnly = builtin;
  $('#dirHint').textContent = builtin
    ? '只能选择已授权的目录。'
    : '外部模式的目录位于远端服务器，需要填写远端绝对路径。';
}

async function saveSettings(event) {
  event.preventDefault();
  const button = $('#saveSettingsBtn');
  setButtonBusy(button, true);
  $('#settingsStatus').textContent = '保存中…';

  try {
    const payload = {
      mode: state.engineMode,
      downloadDir: $('#settingDir').value.trim(),
      maxConcurrent: Number($('#settingConcurrent').value),
      connectionsPerServer: Number($('#settingConnections').value),
      split: Number($('#settingSplit').value),
      downloadLimit: $('#settingDownloadLimit').value.trim(),
      uploadLimit: $('#settingUploadLimit').value.trim(),
      rpcPort: Number($('#settingPort').value),
      deleteFilesByDefault: $('#settingDeleteFiles').checked,
    };

    if (state.engineMode === 'external') {
      payload.externalRpcUrl = $('#settingExternalUrl').value.trim();
      const secret = $('#settingExternalSecret').value;
      if (secret) payload.externalRpcSecret = secret;
    }

    const result = await api('/api/settings', {
      method: 'PUT',
      body: JSON.stringify(payload),
    });

    state.settings = result.settings;
    if (result.engine) {
      if (state.snapshot) state.snapshot.engine = result.engine;
      renderEngine(result.engine);
    }
    if (result.warning) toast(result.warning, 'error');
    toast('设置已保存', 'success');
    $('#settingsStatus').textContent = '已保存';

    await loadSettings();
    fetchSnapshot().catch(() => {});
    setTimeout(() => {
      if ($('#settingsStatus').textContent === '已保存') {
        $('#settingsStatus').textContent = '';
      }
    }, 2600);
  } catch (error) {
    $('#settingsStatus').textContent = '';
    toast(error.message, 'error');
  } finally {
    setButtonBusy(button, false);
  }
}

function openAddModal() {
  state.torrent = null;
  $('#addUris').value = '';
  $('#addTorrent').value = '';
  $('#addDir').value = '';
  $('#torrentHint').textContent = '可选，与上面的链接二选一或同时使用。';
  $('#addDir').placeholder = state.settings
    ? `使用默认目录 ${state.settings.downloadDir}`
    : '使用设置中的默认目录';
  syncAddMode();
  openModal('addModal');
  setTimeout(() => $('#addUris').focus(), 30);
}

function syncAddMode() {
  const builtin = !state.settings || state.settings.mode === 'builtin';
  $('#browseAddDir').classList.toggle('hidden', !builtin);
  $('#addDir').placeholder = builtin
    ? state.settings
      ? `使用默认目录 ${state.settings.downloadDir}`
      : '使用设置中的默认目录'
    : '输入远端服务器上的绝对路径';
}

function toBase64(buffer) {
  const bytes = new Uint8Array(buffer);
  const chunkSize = 0x8000;
  let binary = '';
  for (let index = 0; index < bytes.length; index += chunkSize) {
    binary += String.fromCharCode.apply(
      null,
      bytes.subarray(index, index + chunkSize),
    );
  }
  return btoa(binary);
}

async function handleTorrentChange() {
  const input = $('#addTorrent');
  const file = input.files && input.files[0];
  if (!file) {
    state.torrent = null;
    $('#torrentHint').textContent = '可选，与上面的链接二选一或同时使用。';
    return;
  }
  if (file.size > 20 * 1024 * 1024) {
    toast('种子文件不能超过 20 MB', 'error');
    input.value = '';
    state.torrent = null;
    return;
  }

  try {
    const buffer = await file.arrayBuffer();
    state.torrent = { name: file.name, base64: toBase64(buffer) };
    $('#torrentHint').textContent = `已选择 ${file.name}（${fmtBytes(file.size)}）`;
  } catch (error) {
    state.torrent = null;
    toast(`读取种子文件失败：${error.message}`, 'error');
  }
}

async function submitAdd() {
  const button = $('#submitAdd');
  const uris = $('#addUris')
    .value.split('\n')
    .map((line) => line.trim())
    .filter(Boolean);

  if (uris.length === 0 && !state.torrent) {
    toast('请填写下载链接或选择种子文件', 'error');
    return;
  }

  const payload = { uris };
  const dir = $('#addDir').value.trim();
  if (dir) payload.dir = dir;
  if (state.torrent) payload.torrentBase64 = state.torrent.base64;

  setButtonBusy(button, true);
  try {
    const result = await api('/api/tasks', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
    closeModal('addModal');
    toast(`已添加 ${result.gids.length} 个下载任务`, 'success');
    switchView('active');
    await fetchSnapshot();
  } catch (error) {
    toast(error.message, 'error');
  } finally {
    setButtonBusy(button, false);
  }
}

function requestDelete(gid) {
  const task = findTask(gid);
  state.pendingDelete = { gid, name: task ? task.name : gid };
  $('#deleteTaskName').textContent = task ? task.name : gid;

  const builtin = !state.settings || state.settings.mode === 'builtin';
  const active = Boolean(task && task.isActive);
  const row = $('#deleteFilesRow');
  const checkbox = $('#deleteFiles');
  const hint = $('#deleteFilesHint');

  row.classList.toggle('hidden', !builtin);
  hint.classList.toggle('hidden', builtin);
  checkbox.disabled = active || !builtin;
  checkbox.checked =
    builtin &&
    !active &&
    Boolean(state.settings && state.settings.deleteFilesByDefault);

  openModal('deleteModal');
}

async function confirmDelete() {
  if (!state.pendingDelete) return;
  const button = $('#confirmDelete');
  const gid = state.pendingDelete.gid;
  const deleteFiles = $('#deleteFiles').checked && !$('#deleteFiles').disabled;

  setButtonBusy(button, true);
  try {
    const result = await api(
      `/api/tasks/${encodeURIComponent(gid)}?deleteFiles=${deleteFiles ? 1 : 0}`,
      { method: 'DELETE' },
    );
    closeModal('deleteModal');
    state.pendingDelete = null;
    state.stoppedLoaded = 20;

    const failed = result.files && result.files.failed ? result.files.failed.length : 0;
    if (deleteFiles && failed > 0) {
      toast(`任务已删除，但有 ${failed} 个文件删除失败`, 'error');
    } else if (deleteFiles) {
      toast('任务和文件已删除', 'success');
    } else {
      toast('任务已删除', 'success');
    }

    await fetchSnapshot();
  } catch (error) {
    toast(error.message, 'error');
  } finally {
    setButtonBusy(button, false);
  }
}

async function handleTaskAction(event) {
  const button = event.target.closest('[data-action]');
  if (!button) return;

  const action = button.dataset.action;
  const gid = button.dataset.gid;
  if (!gid) return;

  if (action === 'delete') {
    requestDelete(gid);
    return;
  }

  setButtonBusy(button, true);
  try {
    await api(`/api/tasks/${encodeURIComponent(gid)}/${action}`, { method: 'POST' });
    await fetchSnapshot();
  } catch (error) {
    toast(error.message, 'error');
  } finally {
    setButtonBusy(button, false);
  }
}

async function purgeHistory() {
  if (!window.confirm('清空所有已完成记录？已下载的文件不会被删除。')) return;
  try {
    await api('/api/history/purge', { method: 'POST' });
    state.stoppedLoaded = 20;
    toast('已完成记录已清空', 'success');
    await fetchSnapshot();
  } catch (error) {
    toast(error.message, 'error');
  }
}

async function restartEngine() {
  if (!window.confirm('重启内置 aria2 引擎？正在进行的任务会短暂中断。')) return;
  const button = $('#restartEngineBtn');
  setButtonBusy(button, true);
  try {
    const result = await api('/api/engine/restart', { method: 'POST' });
    if (result.engine) {
      if (state.snapshot) state.snapshot.engine = result.engine;
      renderEngine(result.engine);
    }
    toast('引擎已重启', 'success');
    await fetchSnapshot();
  } catch (error) {
    toast(error.message, 'error');
  } finally {
    setButtonBusy(button, false);
  }
}

async function showLog() {
  try {
    const data = await api('/api/logs/tail?lines=80');
    $('#logPath').textContent = data.path || '';
    $('#logContent').textContent = data.lines || '（日志为空）';
    openModal('logModal');
  } catch (error) {
    toast(error.message, 'error');
  }
}

async function openBrowse(target) {
  if (state.engineMode !== 'builtin') {
    toast('外部 aria2 模式不支持浏览本机目录', 'error');
    return;
  }

  state.browse.target = target;
  openModal('browseModal');

  try {
    const data = await api('/api/fs/roots');
    state.roots = data.roots || [];
    renderBrowseRoots();
    const input = target === 'add' ? $('#addDir') : $('#settingDir');
    const start = input.value.trim() || state.roots[0] || '';
    if (!start) {
      $('#browsePath').textContent = '没有授权目录';
      $('#browseList').innerHTML =
        '<div class="browse-empty">请先在飞牛「应用设置 → 授权目录」中添加目录</div>';
      return;
    }
    await browseTo(start);
  } catch (error) {
    toast(error.message, 'error');
  }
}

function renderBrowseRoots() {
  $('#browseRoots').innerHTML = state.roots
    .map(
      (root) =>
        `<button type="button" class="root-chip" data-browse-root="${escapeHtml(root)}" title="${escapeHtml(root)}">${escapeHtml(root)}</button>`,
    )
    .join('');
}

async function browseTo(path) {
  const data = await api(`/api/fs/list?path=${encodeURIComponent(path)}`);
  state.browse.path = data.path;
  state.browse.parent = data.parent;
  $('#browsePath').textContent = data.path;
  $('#browseUp').disabled = !data.parent;

  if (!data.entries || data.entries.length === 0) {
    $('#browseList').innerHTML = '<div class="browse-empty">这个目录下没有子目录</div>';
    return;
  }

  $('#browseList').innerHTML = data.entries
    .map(
      (entry) =>
        `<button type="button" class="browse-item" data-browse-path="${escapeHtml(entry.path)}">${icon('folder')}<span>${escapeHtml(entry.name)}</span></button>`,
    )
    .join('');
}

function selectBrowsePath() {
  if (!state.browse.path) return;
  if (state.browse.target === 'add') {
    $('#addDir').value = state.browse.path;
  } else {
    $('#settingDir').value = state.browse.path;
  }
  closeModal('browseModal');
}

function bindEvents() {
  $$('[data-view]').forEach((button) => {
    button.addEventListener('click', () => switchView(button.dataset.view));
  });

  ['#sidebarAdd', '#topAdd', '#mobileAdd'].forEach((selector) => {
    const element = $(selector);
    if (element) element.addEventListener('click', openAddModal);
  });

  $('#refreshBtn').addEventListener('click', () => {
    fetchSnapshot().catch((error) => toast(error.message, 'error'));
  });

  $('#settingsForm').addEventListener('submit', saveSettings);
  $('#purgeBtn').addEventListener('click', purgeHistory);
  $('#loadMoreBtn').addEventListener('click', () => {
    loadStopped(state.stoppedLoaded + 20).catch((error) => toast(error.message, 'error'));
  });

  $('#confirmDelete').addEventListener('click', confirmDelete);
  $('#submitAdd').addEventListener('click', submitAdd);
  $('#addTorrent').addEventListener('change', handleTorrentChange);
  $('#browseAddDir').addEventListener('click', () => openBrowse('add'));
  $('#browseSettingDir').addEventListener('click', () => openBrowse('settings'));

  $('#browseUp').addEventListener('click', () => {
    if (state.browse.parent) {
      browseTo(state.browse.parent).catch((error) => toast(error.message, 'error'));
    }
  });
  $('#browseSelect').addEventListener('click', selectBrowsePath);

  $$('.segment').forEach((button) => {
    button.addEventListener('click', () => setMode(button.dataset.mode));
  });

  $('#restartEngineBtn').addEventListener('click', restartEngine);
  $('#showLogBtn').addEventListener('click', showLog);

  $('#rootsList').addEventListener('click', (event) => {
    const chip = event.target.closest('[data-root]');
    if (!chip) return;
    $('#settingDir').value = chip.dataset.root;
  });

  $('#browseRoots').addEventListener('click', (event) => {
    const chip = event.target.closest('[data-browse-root]');
    if (!chip) return;
    browseTo(chip.dataset.browseRoot).catch((error) => toast(error.message, 'error'));
  });

  $('#browseList').addEventListener('click', (event) => {
    const entry = event.target.closest('[data-browse-path]');
    if (!entry) return;
    browseTo(entry.dataset.browsePath).catch((error) => toast(error.message, 'error'));
  });

  $('#activeList').addEventListener('click', handleTaskAction);
  $('#stoppedList').addEventListener('click', handleTaskAction);

  $$('[data-close]').forEach((button) => {
    button.addEventListener('click', () => closeModal(button.dataset.close));
  });

  $$('.modal').forEach((modal) => {
    modal.addEventListener('click', (event) => {
      if (event.target === modal) closeModal(modal.id);
    });
  });

  document.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape') return;
    $$('.modal:not(.hidden)').forEach((modal) => closeModal(modal.id));
  });
}

function init() {
  hydrateIcons();
  bindEvents();
  connectStream();
  fetchSnapshot().catch(() => {});
  loadSettings().catch(() => {});
}

document.addEventListener('DOMContentLoaded', init);
