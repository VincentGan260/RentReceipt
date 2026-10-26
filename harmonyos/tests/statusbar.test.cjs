const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const Module = require('node:module');
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript');
require.extensions['.ets'] = (module, filename) => module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 }
}).outputText, filename);
const values = new Map([['colorMode', 0]]);
const preferences = { async getPreferences() { return {
  async get(key, fallback) { return values.has(key) ? values.get(key) : fallback; },
  async put(key, value) { values.set(key, value); }, async flush() {}
}; } };
const colors = { COLOR_MODE_DARK: 0, COLOR_MODE_LIGHT: 1, COLOR_MODE_NOT_SET: -1 };
const deviceInfo = { sdkApiVersion: 22 };
const originalLoad = Module._load;
Module._load = function(name, ...args) {
  if (name === '@kit.AbilityKit') return { ConfigurationConstant: { ColorMode: colors } };
  if (name === '@kit.ArkData') return { preferences };
  if (name === '@kit.BasicServicesKit') return { deviceInfo };
  if (name === '@kit.ArkUI') return {};
  if (name === '@kit.PerformanceAnalysisKit') return { hilog: { warn() {} } };
  return originalLoad.call(this, name, ...args);
};
const { Appearance } = require('../entry/src/main/ets/data/Appearance.ets');
Module._load = originalLoad;
const storage = new Map();
global.AppStorage = { setOrCreate(key, value) { storage.set(key, value); } };
const tick = () => new Promise(resolve => setImmediate(resolve));

test('saved theme, live overrides and following system keep status icons readable', async () => {
  const calls = [], applied = [];
  const context = { config: { colorMode: colors.COLOR_MODE_LIGHT },
    getApplicationContext() { return { setColorMode(mode) { applied.push(mode); } }; } };
  const mainWindow = { async setWindowSystemBarProperties(properties) { calls.push(properties); } };
  await Appearance.open(context);
  Appearance.bindWindow(mainWindow, context.config.colorMode); await tick();
  assert.equal(calls.at(-1).statusBarContentColor, '#FFFFFF', 'saved dark overrides light system');
  await Appearance.update(context, 1); await tick();
  assert.equal(calls.at(-1).statusBarContentColor, '#000000');
  Appearance.syncSystemBars(colors.COLOR_MODE_DARK); await tick();
  assert.equal(calls.at(-1).statusBarContentColor, '#000000', 'explicit light overrides configuration');
  await Appearance.update(context, -1);
  Appearance.syncSystemBars(colors.COLOR_MODE_DARK); await tick();
  assert.equal(calls.at(-1).statusBarContentColor, '#FFFFFF');
  Appearance.syncSystemBars(colors.COLOR_MODE_LIGHT); await tick();
  assert.equal(calls.at(-1).statusBarContentColor, '#000000');
  assert.ok(calls.every(call => call.statusBarColor === '#00000000'));
  assert.ok(calls.every(call => !('isStatusBarLightIcon' in call)), 'avoid conflicting icon flags');
  assert.deepEqual(applied, [0, 1, -1]);
  Appearance.unbindWindow();
});

test('queued updates cannot target a destroyed window and a failed update can retry', async () => {
  let attempts = 0;
  Appearance.mode = -1;
  const mainWindow = { async setWindowSystemBarProperties() {
    attempts++; if (attempts === 1) throw Error('window temporarily unavailable');
  } };
  Appearance.bindWindow(mainWindow, colors.COLOR_MODE_LIGHT); await tick();
  Appearance.syncSystemBars(colors.COLOR_MODE_DARK); await tick();
  assert.equal(attempts, 2);
  Appearance.syncSystemBars(colors.COLOR_MODE_LIGHT); Appearance.unbindWindow(); await tick();
  assert.equal(attempts, 2);
});


test('HDS owns status icons and observes both navigation scroll states on every page', async () => {
  deviceInfo.sdkApiVersion = 23;
  let windowWrites = 0;
  Appearance.mode = -1;
  Appearance.bindWindow({ async setWindowSystemBarProperties() { windowWrites++; } }, colors.COLOR_MODE_LIGHT);
  assert.equal(storage.get('statusBarContentColor'), '#000000');
  Appearance.syncSystemBars(colors.COLOR_MODE_DARK);
  assert.equal(storage.get('statusBarContentColor'), '#FFFFFF');
  await tick();
  assert.equal(windowWrites, 0, 'window API must not compete with HDS navigation');
  const path = require('node:path');
  const root = path.join(__dirname, '../entry/src/main/ets');
  const files = [path.join(root, 'pages/Index.ets'), ...fs.readdirSync(path.join(root, 'ui')).map(f => path.join(root, 'ui', f))];
  for (const file of files) {
    const source = fs.readFileSync(file, 'utf8');
    const navigationCount = (source.match(/HdsNavDestination\(\)|HdsNavigation\(this.paths\)/g) || []).length;
    if (!navigationCount) continue;
    assert.ok(source.includes("@StorageLink('statusBarContentColor')"), file);
    assert.equal((source.match(/\.systemBarStyle\(\{ statusBarContentColor: this.statusBarContentColor \},\s*\{ statusBarContentColor: this.statusBarContentColor \}\)/g) || []).length, navigationCount, file);
  }
  Appearance.unbindWindow();
});

test('compact native tab and search group has equal outside margins and an 8vp gap', () => {
  const source = fs.readFileSync(require('node:path').join(__dirname, '../entry/src/main/ets/pages/Index.ets'), 'utf8');
  const compact = source.match(/private compactTabWidth\(\): number \{[^\n]+/)[0];
  const margin = source.match(/private tabSideMargin\(\): number \{[\s\S]*?\n  \}/)[0];
  const compiled = ts.transpileModule('class Layout { contentWidth=360; searching=false; pageMargin(){return 16;} ' + compact + margin + '} exports.Layout=Layout;', {compilerOptions:{target:ts.ScriptTarget.ES2021}}).outputText;
  const exported = {}; new Function('exports', compiled)(exported);
  for (const width of [344, 360, 390, 400, 412, 439]) {
    const layout = new exported.Layout(); layout.contentWidth = width;
    const side = layout.tabSideMargin();
    assert.equal(width - side * 2 - layout.compactTabWidth() - 56, 8, String(width));
  }
  assert.ok(source.includes('barSideMargin: this.tabSideMargin()'));
});
