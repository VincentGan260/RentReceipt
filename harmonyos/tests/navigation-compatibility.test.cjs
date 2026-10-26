const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript');
const root = path.join(__dirname, '../entry/src/main/ets');
const source = fs.readFileSync(path.join(root, 'pages/Index.ets'), 'utf8');
const navigation = fs.readFileSync(path.join(root, 'ui/ImmersiveNavigation.ets'), 'utf8');

test('legacy startup never constructs a controller absent from the system module', () => {
  const initializer = source.match(/private homeTabsController[^=]*= ([^;]+);/)[1];
  const compiled = ts.transpileModule('return ' + initializer + ';', {}).outputText;
  const create = new Function('hds', compiled);
  assert.equal(create.call({ immersiveNavigation: false }, {}), undefined);
  let constructed = 0;
  class Controller { constructor() { constructed++; } }
  assert.ok(create.call({ immersiveNavigation: true }, { HdsTabsController: Controller }) instanceof Controller);
  assert.equal(constructed, 1);
});

test('startup modules do not statically link newer named exports or the material module', () => {
  const newerExports = new Set(['HdsTabs', 'HdsTabsController', 'HdsBarStyle', 'HdsTabsBarChangeMode', 'hdsMaterial']);
  for (const text of [source, navigation]) {
    const ast = ts.createSourceFile('navigation.ts', text, ts.ScriptTarget.Latest, true);
    for (const statement of ast.statements) {
      if (!ts.isImportDeclaration(statement)) continue;
      assert.notEqual(statement.moduleSpecifier.text, '@hms.hds.hdsMaterial');
      const bindings = statement.importClause?.namedBindings;
      if (!bindings || !ts.isNamedImports(bindings)) continue;
      for (const item of bindings.elements) {
        const name = (item.propertyName || item.name).text;
        assert.ok(!newerExports.has(name), `unsafe eager import: ${name}`);
      }
    }
  }
});
