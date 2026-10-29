// Generate synthetic v10 data using production serializers/calculators.
const fs = require('node:fs');
const path = require('node:path');
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript');
require.extensions['.ets'] = (m, f) => m._compile(ts.transpileModule(fs.readFileSync(f, 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 }
}).outputText, f);
const base = path.resolve(__dirname, '../harmonyos/entry/src/main/ets');
const M = require(base + '/model/Models.ets');
const C = require(base + '/model/BillCalculator.ets');
const B = require(base + '/data/BackupTables.ets');
const data = M.initialData();
const building = data.buildings[0];
building.name = '功能同步测试楼';
building.settings.defaultWaterRate = '5';
building.settings.defaultElectricityRate = '1';
building.settings.defaultManagementRate = '0.2';
const room = (number, extra = {}) => Object.assign(new M.Room(), {
  id: 'sync-room-' + number, buildingId: building.id, number, rent: '1000', occupied: true,
  recurringCharges: [{ name: '网费', amount: '30' }]
}, extra);
data.rooms = [room('101'), room('102', { customWaterRate: '7', customElectricityRate: '2', customManagementRate: '0' }),
  room('103'), room('104'), room('105'), room('106')];
for (const r of data.rooms) {
  const draft = Object.assign(new M.BillDraft(), { month: '2026-10', previousWater: '100', currentWater: '110',
    previousElectricity: '1000', currentElectricity: '1100', customCharges: r.recurringCharges });
  data.bills.push(C.createBill(r, building.settings, draft, r.id + '-2026-10'));
  if (['101', '102', '103'].includes(r.number)) {
    draft.month = '2026-11'; draft.previousWater = '110'; draft.currentWater = '120';
    draft.previousElectricity = '1100'; draft.currentElectricity = '1200';
    if (r.number === '103') { draft.waterUsageOverride = '8'; draft.electricityUsageOverride = '50';
      draft.customCharges = r.recurringCharges.concat([{ name: '门卡补办', amount: '20' }, { name: '补收2026年9月房租', amount: '1000' }]); }
    const bill = C.createBill(r, building.settings, draft, r.id + '-2026-11');
    if (r.number === '103') { bill.paid = true; bill.paidDate = '2026-11-02'; }
    data.bills.push(bill);
  }
}
const files = B.exportTables(data);
const restored = B.importTables(files);
if (restored.rooms.length !== 6 || restored.bills.length !== 9) throw new Error('Fixture round trip failed');
const output = path.resolve(__dirname, '../outputs/harmonyos-sync-sample');
fs.mkdirSync(output, { recursive: true });
for (const file of files) fs.writeFileSync(path.join(output, file.name), '\uFEFF' + file.text);
console.log(output);

const { StoredState, decodeState } = require(base + '/data/RentStore.ets');
const snapshot = new StoredState(); snapshot.data = restored;
const content = JSON.stringify(snapshot);
decodeState(content);
fs.writeFileSync(path.join(output, 'simulator-state.json'), content);

const Z = require(base + '/data/BackupZip.ets');
const zip = Z.writeZip(files.map(file => ({ name: file.name, bytes: new Uint8Array(Buffer.from('\uFEFF' + file.text)) })));
fs.writeFileSync(path.join(output, '../鸿蒙功能同步测试样例-v10.zip'), zip);
console.log('ZIP sample generated');
