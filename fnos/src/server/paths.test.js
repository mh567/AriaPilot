'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const { AuthorizedPaths, isPathInside } = require('./paths');

function tempDir(prefix = 'ariapilot-paths-') {
  return fs.mkdtempSync(path.join(os.tmpdir(), prefix));
}

test('isPathInside only matches real descendants', () => {
  assert.equal(isPathInside('/data/downloads/a', '/data/downloads'), true);
  assert.equal(isPathInside('/data/downloads', '/data/downloads'), true);
  assert.equal(isPathInside('/data/downloads-evil/a', '/data/downloads'), false);
  assert.equal(isPathInside('/data', '/data/downloads'), false);
  assert.equal(isPathInside('/data/downloads/../secret', '/data/downloads'), false);
});

test('contains rejects traversal outside the authorized root', () => {
  const base = tempDir();
  const root = path.join(base, 'root');
  const outside = path.join(base, 'outside');
  fs.mkdirSync(root);
  fs.mkdirSync(outside);

  const paths = new AuthorizedPaths({ envPaths: [root] });

  assert.equal(paths.contains(path.join(root, 'downloads')), true);
  assert.equal(paths.contains(path.join(root, '..', 'outside')), false);
  assert.equal(paths.contains(outside), false);
});

test('contains follows symlinks and rejects escapes', () => {
  const base = tempDir();
  const root = path.join(base, 'root');
  const outside = path.join(base, 'outside');
  fs.mkdirSync(root);
  fs.mkdirSync(outside);
  fs.writeFileSync(path.join(outside, 'secret.txt'), 'secret');

  const link = path.join(root, 'leak');
  fs.symlinkSync(outside, link);

  const paths = new AuthorizedPaths({ envPaths: [root] });
  assert.equal(paths.contains(link), false);
  assert.equal(paths.contains(path.join(link, 'secret.txt')), false);

  const listing = paths.list(root);
  assert.deepEqual(listing.entries.map((entry) => entry.name), []);
});

test('ensureDirectory creates a directory and verifies it is writable', () => {
  const base = tempDir();
  const root = path.join(base, 'root');
  fs.mkdirSync(root);

  const paths = new AuthorizedPaths({ envPaths: [root] });
  const target = path.join(root, 'AriaPilot');
  const resolved = paths.ensureDirectory(target);

  assert.equal(fs.statSync(resolved).isDirectory(), true);
  assert.equal(paths.contains(resolved), true);
  assert.throws(() => paths.ensureDirectory(path.join(base, 'nope')), /授权/);
});

test('list returns only directories inside the root', () => {
  const base = tempDir();
  const root = path.join(base, 'root');
  const child = path.join(root, 'child');
  fs.mkdirSync(child, { recursive: true });
  fs.writeFileSync(path.join(root, 'file.txt'), 'x');
  fs.mkdirSync(path.join(root, '.hidden'));

  const paths = new AuthorizedPaths({ envPaths: [root] });
  const listing = paths.list();
  const realRoot = fs.realpathSync(root);

  assert.equal(listing.path, realRoot);
  assert.equal(listing.parent, null);
  assert.deepEqual(listing.entries.map((entry) => entry.name), ['child']);
  assert.equal(paths.list(child).parent, realRoot);
});

test('deleteFiles skips symlinks and paths outside the root', () => {
  const base = tempDir();
  const root = path.join(base, 'root');
  const downloads = path.join(root, 'downloads');
  const nested = path.join(downloads, 'nested');
  const outside = path.join(base, 'outside.bin');
  fs.mkdirSync(nested, { recursive: true });
  fs.writeFileSync(path.join(downloads, 'a.bin'), 'a');
  fs.writeFileSync(path.join(downloads, 'a.bin.aria2'), 'control');
  fs.writeFileSync(path.join(nested, 'b.bin'), 'b');
  fs.writeFileSync(outside, 'outside');
  fs.symlinkSync(outside, path.join(downloads, 'link.bin'));

  const paths = new AuthorizedPaths({ envPaths: [root] });
  const result = paths.deleteFiles(
    [
      { path: path.join(downloads, 'a.bin') },
      { path: path.join(nested, 'b.bin') },
      { path: path.join(downloads, 'link.bin') },
      { path: outside },
      { path: path.join(downloads, 'missing.bin') },
    ],
    downloads,
  );

  assert.equal(fs.existsSync(path.join(downloads, 'a.bin')), false);
  assert.equal(fs.existsSync(path.join(downloads, 'a.bin.aria2')), false);
  assert.equal(fs.existsSync(path.join(nested, 'b.bin')), false);
  assert.equal(fs.existsSync(outside), true);
  assert.equal(fs.existsSync(path.join(downloads, 'link.bin')), true);
  assert.equal(result.deleted.length, 3);
  assert.equal(result.failed.length, 1);
  assert.equal(result.skipped.length, 6);
});
