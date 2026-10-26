const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const Module = require('node:module');
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript');
require.extensions['.ets'] = (module, filename) => {
  module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 }
  }).outputText, filename);
};

// Host adapter exercises the production storage algorithm and failure paths.
// HarmonyOS file API behavior still needs simulator/remote-device verification.
let failure;
let closes = 0;
const handles = new Map();
const fileIo = {
  OpenMode: { CREATE: 1, WRITE_ONLY: 2, TRUNC: 4 },
  accessSync: filename => fs.existsSync(filename),
  readText: filename => fs.promises.readFile(filename, 'utf8'),
  async open(filename) {
    if (failure === 'open') throw new Error('open failed');
    const handle = await fs.promises.open(filename, 'w'); handles.set(handle.fd, handle);
    return { fd: handle.fd };
  },
  async write(fd, buffer) {
    const bytes = Buffer.from(buffer);
    if (failure === 'short') return (await handles.get(fd).write(bytes.subarray(0, 3))).bytesWritten;
    if (failure === 'write') throw new Error('write failed');
    return (await handles.get(fd).write(bytes)).bytesWritten;
  },
  async fsync(fd) {
    if (failure === 'sync') throw new Error('sync failed');
    await handles.get(fd).sync();
  },
  async close(file) { closes++; const handle = handles.get(file.fd); handles.delete(file.fd); await handle.close(); },
  async rename(from, to) {
    if (failure === 'rename') throw new Error('rename failed');
    await fs.promises.rename(from, to);
  }
};
const originalLoad = Module._load;
Module._load = function(name, ...args) {
  if (name === '@kit.CoreFileKit') return { fileIo };
  if (name === '@kit.ArkTS') return { util: { TextEncoder: class { encodeInto(value) { return new TextEncoder().encode(value); } } } };
  return originalLoad.call(this, name, ...args);
};
const { LocalSnapshotStorage } = require('../entry/src/main/ets/data/LocalSnapshotStorage.ets');
Module._load = originalLoad;

test('atomic UTF-8 writes round-trip Chinese data and retain old snapshot on failures', async () => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'rentreceipt-storage-'));
  try {
    const storage = new LocalSnapshotStorage(temporary);
    assert.equal(await storage.read(), undefined);
    const old = JSON.stringify({ 楼栋: '南楼🏠', 房租: '9007199254740993' });
    await storage.write(old); assert.equal(await storage.read(), old);
    for (const stage of ['open', 'write', 'short', 'sync', 'rename']) {
      const before = closes;
      failure = stage;
      await assert.rejects(storage.write('新数据，不能覆盖原文件'), /保存失败/);
      assert.equal(await storage.read(), old, stage);
      assert.equal(handles.size, 0, stage);
      if (stage !== 'open') assert.equal(closes, before + 1);
    }
    failure = undefined;
    await storage.write('重试保存成功'); assert.equal(await storage.read(), '重试保存成功');
  } finally { failure = undefined; fs.rmSync(temporary, { recursive: true, force: true }); }
});
