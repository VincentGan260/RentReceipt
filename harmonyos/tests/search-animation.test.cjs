const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript');
const source = fs.readFileSync(require('node:path').join(__dirname, '../entry/src/main/ets/pages/Index.ets'), 'utf8');
function blockAfter(marker) {
  const start = source.indexOf(marker);
  assert.ok(start >= 0, marker);
  const open = source.indexOf('{', start);
  let depth = 1, end = open + 1;
  for (; depth; end++) {
    if (source[end] === '{') depth++;
    if (source[end] === '}') depth--;
  }
  return source.slice(open + 1, end - 1);
}
function scenario() {
  const events = [], frames = [];
  const host = { pendingSearchFocus: false, searching: false, miniBarExpanded: false, searchContentVisible: false, query: '101',
    homeTabsController: { applyMiniBarStyle(style) { events.push(['style', style]); } },
    searchController: { stopEditing() { events.push(['stop']); } },
    getUIContext() { return {
      postFrameCallback(frame) { frames.push(frame); },
      getFocusController() { return { requestFocus(id) { events.push(['focus', id]); } }; }
    }; }
  };
  const hds = { HdsBarStyle: { COLLAPSE: 0, EXPAND: 1 }, HdsTabsBarChangeMode: { USER_CLICK: 1 } };
  class SearchFocusFrame { constructor(focus) { this.focus = focus; } onIdle() { this.focus(); } }
  for (const [name, marker] of Object.entries({ begin: 'private beginNativeSearch()', end: 'private endNativeSearch()',
    focusNativeSearch: 'private focusNativeSearch(', change: 'onBarStyleChange:', complete: 'onMiniBarAnimationEnd:' })) {
    const args = name === 'change'
      ? 'miniStyle: number, tabStyle: number, miniWidth: number, tabWidth: number, mode: number'
      : name === 'focusNativeSearch' ? 'attempt: number = 0' : 'style: number';
    const compiled = ts.transpileModule('return function(' + args + ') {' + blockAfter(marker) + '}', {}).outputText;
    host[name] = new Function('hds', 'SearchFocusFrame', compiled)(hds, SearchFocusFrame);
  }
  return { host, events, flush() { while (frames.length) frames.shift().onIdle(); } };
}
test('native expansion queues focus after layout and cancel delegates collapse', () => {
  const { host, events, flush } = scenario();
  host.begin(); host.change(1, 0, 248, 56, 0);
  assert.equal(host.miniBarExpanded, true);
  assert.equal(host.searchContentVisible, true);
  assert.deepEqual(events, [['style', 1]], 'focus waits for layout');
  flush();
  assert.deepEqual(events.at(-1), ['focus', 'nativeRoomSearch']);
  assert.equal(host.searching, true);
  host.complete(1); flush();
  assert.equal(events.filter(event => event[0] === 'focus').length, 1, 'animation end does not refocus');
  host.end();
  assert.equal(host.query, '');
  assert.equal(host.searchContentVisible, false);
  assert.equal(host.searching, false);
  assert.deepEqual(events.slice(-2), [['stop'], ['style', 0]]);
  host.change(0, 1, 56, 248, 0); host.complete(0);
  assert.equal(host.miniBarExpanded, false);
});
test('cancelling an in-flight expansion prevents stale keyboard focus', () => {
  const { host, events, flush } = scenario();
  host.begin(); host.change(1, 0, 248, 56, 0); host.end(); host.complete(1); flush();
  assert.ok(!events.some(event => event[0] === 'focus'));
  assert.equal(host.searching, false);
});
