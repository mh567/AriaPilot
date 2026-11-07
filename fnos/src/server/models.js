'use strict';

const STATUS_LABELS = {
  active: '下载中',
  waiting: '等待中',
  paused: '已暂停',
  complete: '已完成',
  error: '出错',
  removed: '已移除',
};

function numberValue(value) {
  const num = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(num) ? num : 0;
}

function lastSegment(value) {
  if (!value) return '';
  const clean = String(value).replace(/[\\/]+$/, '');
  const parts = clean.split(/[\\/]/);
  return parts[parts.length - 1] || '';
}

function taskName(task) {
  const torrentName =
    task.bittorrent && task.bittorrent.info && task.bittorrent.info.name;
  if (torrentName) return torrentName;

  const files = Array.isArray(task.files) ? task.files : [];
  const firstFile = files[0];
  if (firstFile && firstFile.path) {
    const name = lastSegment(firstFile.path);
    if (name) return name;
  }

  if (
    firstFile &&
    Array.isArray(firstFile.uris) &&
    firstFile.uris[0] &&
    firstFile.uris[0].uri
  ) {
    const name = lastSegment(firstFile.uris[0].uri);
    if (name) return name;
  }

  return task.gid || '未知任务';
}

function friendlyErrorMessage(message, dir) {
  if (!message) return '';
  if (/permission denied|cannot open/i.test(message)) {
    const location = dir ? `（${dir}）` : '';
    return `无法写入下载目录${location}：${message}。请检查目录权限，或删除同名残留文件后重试。`;
  }
  return message;
}

function normalizeTask(task, { canDeleteFiles = false } = {}) {
  const totalLength = numberValue(task.totalLength);
  const completedLength = numberValue(task.completedLength);
  const downloadSpeed = numberValue(task.downloadSpeed);
  const uploadSpeed = numberValue(task.uploadSpeed);
  const status = task.status || 'unknown';

  const files = Array.isArray(task.files)
    ? task.files.map((file) => ({
        path: file.path || '',
        length: numberValue(file.length),
        completedLength: numberValue(file.completedLength),
        selected: String(file.selected) !== 'false',
      }))
    : [];

  const isActive = status === 'active';
  const isPaused = status === 'paused' || status === 'waiting';
  const isComplete = status === 'complete';
  const isError = status === 'error' || status === 'removed';
  const eta =
    downloadSpeed > 0 && totalLength > completedLength
      ? Math.round((totalLength - completedLength) / downloadSpeed)
      : null;

  return {
    gid: task.gid || '',
    name: taskName(task),
    status,
    statusLabel: STATUS_LABELS[status] || status,
    isActive,
    isPaused,
    isComplete,
    isError,
    totalLength,
    completedLength,
    progress: totalLength > 0 ? Math.min(1, completedLength / totalLength) : 0,
    downloadSpeed,
    uploadSpeed,
    eta,
    connections: numberValue(task.connections),
    numSeeders: numberValue(task.numSeeders),
    seeder: String(task.seeder) === 'true',
    errorCode: task.errorCode ? numberValue(task.errorCode) : null,
    errorMessage: friendlyErrorMessage(task.errorMessage, task.dir),
    dir: task.dir || '',
    files,
    fileCount: files.length,
    isTorrent: Boolean(task.bittorrent),
    bittorrentName:
      task.bittorrent && task.bittorrent.info
        ? task.bittorrent.info.name || ''
        : '',
    canDeleteFiles: canDeleteFiles && !isActive,
  };
}

function normalizeGlobalStat(stat = {}) {
  return {
    downloadSpeed: numberValue(stat.downloadSpeed),
    uploadSpeed: numberValue(stat.uploadSpeed),
    numActive: numberValue(stat.numActive),
    numWaiting: numberValue(stat.numWaiting),
    numStopped: numberValue(stat.numStopped),
  };
}

module.exports = {
  STATUS_LABELS,
  friendlyErrorMessage,
  normalizeGlobalStat,
  normalizeTask,
  numberValue,
  taskName,
};
