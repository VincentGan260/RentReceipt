const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { execFileSync } = require('node:child_process');

test('actual iOS sync regression tests pass against production models and AppStore', () => {
  const root = path.resolve(__dirname, '../..');
  const source = path.join(root, 'ios/RentReceipt/RentReceipt');
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'rentreceipt-ios-sync-'));
  try {
    const overview = fs.readFileSync(path.join(source, 'OverviewView.swift'), 'utf8');
    const start = overview.indexOf('struct MonthValue: Hashable {');
    assert.ok(start >= 0);
    let depth = 0, end = start;
    for (; end < overview.length; end++) {
      if (overview[end] === '{') depth++;
      if (overview[end] === '}' && --depth === 0) { end++; break; }
    }
    fs.writeFileSync(path.join(temporary, 'MonthValue.swift'), 'import Foundation\n' + overview.slice(start, end));
    // Run the same XCTest methods as the iOS test target, without requiring a simulator.
    const tests = fs.readFileSync(path.join(root, 'ios/RentReceipt/RentReceiptTests/BillCalculatorTests.swift'), 'utf8');
    const syncTests = tests.slice(tests.indexOf('extension BillCalculatorTests {'));
    assert.ok(syncTests.includes('testFeeConfirmationDoesNotChangeBillUntilAccepted'));
    fs.writeFileSync(path.join(temporary, 'SyncTests.swift'), 'import XCTest\nfinal class BillCalculatorTests: XCTestCase {}\n' + syncTests);
    fs.writeFileSync(path.join(temporary, 'main.swift'), `
import XCTest
let suite = BillCalculatorTests.defaultTestSuite
suite.run()
guard let result = suite.testRun, result.executionCount == 6, result.totalFailureCount == 0 else { fatalError("iOS sync tests failed") }
print("Executed 6 tests, with 0 failures")
`);
    const executable = path.join(temporary, 'ios-sync-tests');
    const developer = execFileSync('/usr/bin/xcode-select', ['-p'], { encoding: 'utf8' }).trim();
    const frameworks = path.join(developer, 'Platforms/MacOSX.platform/Developer/Library/Frameworks');
    const libraries = path.join(developer, 'Platforms/MacOSX.platform/Developer/usr/lib');
    execFileSync('/usr/bin/xcrun', ['swiftc', '-F', frameworks, '-I', libraries, '-L', libraries,
      '-Xlinker', '-rpath', '-Xlinker', frameworks, '-Xlinker', '-rpath', '-Xlinker', libraries, '-module-cache-path', path.join(temporary, 'cache'),
      path.join(source, 'Models.swift'), path.join(source, 'BillCalculator.swift'), path.join(source, 'AppStore.swift'),
      path.join(temporary, 'MonthValue.swift'), path.join(temporary, 'SyncTests.swift'), path.join(temporary, 'main.swift'),
      '-o', executable], { timeout: 60000, stdio: 'pipe' });
    const output = execFileSync(executable, [], { encoding: 'utf8', timeout: 30000 });
    assert.match(output, /Executed 6 tests, with 0 failures/);
  } finally { fs.rmSync(temporary, { recursive: true, force: true }); }
});
