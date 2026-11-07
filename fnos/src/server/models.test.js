'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { friendlyErrorMessage, normalizeTask } = require('./models');

test('permission errors are explained in Chinese', () => {
  const message = friendlyErrorMessage(
    'Cannot open /vol1/@appshare/ariapilot/downloads/index.html: Permission denied',
    '/vol1/@appshare/ariapilot/downloads',
  );

  assert.match(message, /无法写入下载目录/);
  assert.match(message, /删除同名残留文件/);
  assert.match(message, /Permission denied/);
});

test('normal download errors are kept unchanged', () => {
  const message = 'HTTP authorization failed';
  assert.equal(friendlyErrorMessage(message, '/downloads'), message);
});

test('normalizeTask exposes the friendly error message', () => {
  const task = normalizeTask({
    gid: '0123456789abcdef',
    status: 'error',
    totalLength: '100',
    completedLength: '10',
    errorCode: '1',
    errorMessage: 'Cannot open /downloads/index.html: Permission denied',
    dir: '/downloads',
    files: [{ path: '/downloads/index.html', length: '100', completedLength: '10' }],
  });

  assert.match(task.errorMessage, /无法写入下载目录/);
  assert.equal(task.isError, true);
  assert.equal(task.fileCount, 1);
});
