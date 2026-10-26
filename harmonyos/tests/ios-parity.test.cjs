const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript');
require.extensions['.ets'] = (module, filename) => {
  module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 }
  }).outputText, filename);
};
const root = path.resolve(__dirname, '../..');
const M = require(root + '/harmonyos/entry/src/main/ets/model/Models.ets');
const C = require(root + '/harmonyos/entry/src/main/ets/model/BillCalculator.ets');

test('80 bill fixtures match actual iOS v1.2 calculator field by field', () => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'rentreceipt-ios-parity-'));
  try {
    const fixtures = [];
    for (let i = 0; i < 80; i++) {
      const room = Object.assign(new M.Room(), { id: 'r' + i, number: '铺' + i, rent: String(500 + i) + '.5' });
      const settings = Object.assign(new M.PricingSettings(), {
        defaultWaterRate: '5.25', defaultElectricityRate: '1.30', defaultManagementRate: i % 3 ? '0.25' : ''
      });
      if (i % 4 === 0) Object.assign(room, { customWaterRate: '6', customElectricityRate: '1.25', customManagementRate: '0' });
      const draft = Object.assign(new M.BillDraft(), {
        month: '2026-' + String(i % 12 + 1).padStart(2, '0'),
        previousWater: '100.2', currentWater: '103.7', previousElectricity: '1000', currentElectricity: String(1010 + i) + '.5',
        customCharges: [{ name: ' 网络费 ', amount: '29.5' }, { name: '卫生费', amount: '0.49' }]
      });
      if (i % 5 === 0) Object.assign(draft, { previousElectricity: '9999', currentElectricity: String(i) });
      if (i % 7 === 0) draft.electricityUsageOverride = '50.5';
      if (i % 8 === 0) draft.rentOnly = true;
      fixtures.push({ room, settings, draft });
    }
    fs.writeFileSync(path.join(temporary, 'fixtures.json'), JSON.stringify(fixtures));
    // MonthValue is declared after the SwiftUI screen. Extract the actual
    // Foundation-only declaration so the existing model can compile on macOS.
    const overview = fs.readFileSync(root + '/ios/RentReceipt/RentReceipt/OverviewView.swift', 'utf8');
    const start = overview.indexOf('struct MonthValue: Hashable {');
    assert.ok(start >= 0, 'MonthValue declaration missing');
    let depth = 0, end = start;
    for (; end < overview.length; end++) {
      if (overview[end] === '{') depth++;
      if (overview[end] === '}' && --depth === 0) { end++; break; }
    }
    fs.writeFileSync(path.join(temporary, 'MonthValue.swift'), 'import Foundation\n' + overview.slice(start, end));
    fs.writeFileSync(path.join(temporary, 'main.swift'), `
import Foundation
struct Fixture: Decodable { var room: Room; var settings: PricingSettings; var draft: BillDraft }
let input = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
let fixtures = try JSONDecoder().decode([Fixture].self, from: input)
let result = try fixtures.map { try BillCalculator.makeBill(room: $0.room, settings: $0.settings, draft: $0.draft) }
FileHandle.standardOutput.write(try JSONEncoder().encode(result))
`);
    const executable = path.join(temporary, 'parity');
    execFileSync('/usr/bin/xcrun', ['swiftc', '-module-cache-path', path.join(temporary, 'cache'),
      root + '/ios/RentReceipt/RentReceipt/Models.swift', root + '/ios/RentReceipt/RentReceipt/BillCalculator.swift',
      path.join(temporary, 'MonthValue.swift'), path.join(temporary, 'main.swift'), '-o', executable], { timeout: 60000, stdio: 'pipe' });
    const ios = JSON.parse(execFileSync(executable, [path.join(temporary, 'fixtures.json')], { encoding: 'utf8' }));
    const fields = ['buildingId', 'roomId', 'roomNumber', 'month', 'createdDate', 'previousWater', 'currentWater',
      'waterRate', 'waterAmount', 'previousElectricity', 'currentElectricity', 'electricityRate', 'electricityAmount',
      'rent', 'total', 'rentOnly', 'paid', 'paidDate', 'waterUsage', 'electricityUsage', 'managementRate', 'managementAmount'];
    fixtures.forEach((fixture, index) => {
      const actual = C.createBill(fixture.room, fixture.settings, fixture.draft, 'test');
      for (const field of fields) assert.equal(actual[field], ios[index][field], 'fixture ' + index + ': ' + field);
      assert.deepEqual(JSON.parse(JSON.stringify(actual.customCharges)), ios[index].customCharges);
    });
  } finally { fs.rmSync(temporary, { recursive: true, force: true }); }
});


test('actual iOS store preserves payment dates and clears only obsolete drafts', () => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'rentreceipt-store-parity-'));
  try {
    const overview = fs.readFileSync(root + '/ios/RentReceipt/RentReceipt/OverviewView.swift', 'utf8');
    const start = overview.indexOf('struct MonthValue: Hashable {');
    fs.writeFileSync(path.join(temporary, 'MonthValue.swift'), 'import Foundation\n' + overview.slice(start));
    fs.writeFileSync(path.join(temporary, 'Runner.swift'), `
import Foundation
@main struct Runner {
  @MainActor static func main() throws {
    let file = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("data.json")
    let store = AppStore(fileURL: file)
    let room = Room(id: "r1", number: "101", rent: "800", buildingId: defaultBuildingID)
    let other = Room(id: "r2", number: "102", rent: "900", buildingId: defaultBuildingID)
    store.upsert(room); store.upsert(other)
    let draft = BillDraft(month: "2026-08", previousWater: "100", currentWater: "110",
                          previousElectricity: "1000", currentElectricity: "1050")
    var paid = try BillCalculator.makeBill(room: room, settings: PricingSettings(), draft: draft)
    paid.paid = true; paid.paidDate = "2026-08-02"
    store.upsert(paid)
    store.upsert(try BillCalculator.makeBill(room: other, settings: PricingSettings(), draft: draft))
    store.setMonthPaid(month: "2026-08", paid: true)
    precondition(store.data.bills.first { $0.roomId == room.id }!.paidDate == "2026-08-02")
    precondition(store.data.bills.allSatisfy { $0.paid })
    store.upsert(try BillCalculator.makeBill(room: room, settings: PricingSettings(), draft: draft))
    precondition(store.data.bills.first { $0.roomId == room.id }!.paidDate == "2026-08-02")
    store.setMonthPaid(month: "2026-08", paid: false)
    precondition(store.data.bills.allSatisfy { !$0.paid && $0.paidDate == nil })
    store.saveDraft(draft, roomID: room.id); store.saveDraft(draft, roomID: other.id)
    store.deleteRoom(id: room.id)
    precondition(store.draft(roomID: room.id, month: draft.month) == nil)
    precondition(store.draft(roomID: other.id, month: draft.month) != nil)
    precondition(store.data.bills.count == 2)
    store.replaceAll(with: store.data); store.flush()
    let reopened = AppStore(fileURL: file)
    precondition(reopened.draft(roomID: other.id, month: draft.month) == nil)
    precondition(reopened.data.bills.count == 2)
    for input in ["12abc", "1.2.3", "NaN", "--1", ""] {
      do { _ = try BillCalculator.decimal(input); preconditionFailure("accepted invalid number") }
      catch { }
    }
    let exponent = try BillCalculator.decimal(" 1.25e2 "); precondition(exponent == 125)
    for month in ["2026-13", "0000-01", "2026-1", "2026-01suffix"] {
      precondition(MonthValue.parse(month) == nil)
    }
  }
}
`);
    const executable = path.join(temporary, 'check');
    const swift = root + '/ios/RentReceipt/RentReceipt/';
    execFileSync('/usr/bin/xcrun', ['swiftc', '-parse-as-library', '-module-cache-path', path.join(temporary, 'cache'),
      swift + 'Models.swift', swift + 'BillCalculator.swift', swift + 'AppStore.swift',
      path.join(temporary, 'MonthValue.swift'), path.join(temporary, 'Runner.swift'), '-o', executable], {timeout: 60000, stdio: 'pipe'});
    execFileSync(executable, [temporary], {timeout: 10000, stdio: 'pipe'});
  } finally { fs.rmSync(temporary, {recursive: true, force: true}); }
});
