const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript');

// Execute the exact .ets domain sources; the native build separately checks ArkTS.
require.extensions['.ets'] = (module, filename) => {
  const compiled = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 }
  });
  module._compile(compiled.outputText, filename);
};
const root = path.resolve(__dirname, '../entry/src/main/ets');
const { Decimal: D } = require(root + '/model/Decimal.ets');
const M = require(root + '/model/Models.ets');
const C = require(root + '/model/BillCalculator.ets');
const { RentStore, decodeState, StoredState } = require(root + '/data/RentStore.ets');

function room(overrides = {}) { return Object.assign(new M.Room(), { id: 'room-101', number: '101', rent: '650' }, overrides); }
function settings(overrides = {}) { return Object.assign(new M.PricingSettings(), overrides); }
function draft(overrides = {}) {
  return Object.assign(new M.BillDraft(), {
    month: '2026-08', previousWater: '513', currentWater: '515', previousElectricity: '3123', currentElectricity: '3257'
  }, overrides);
}
function bill(r = room(), s = settings(), d = draft()) { return C.createBill(r, s, d, 'bill-1'); }
class Storage {
  content;
  fail = false;
  writes = 0;
  async read() { return this.content; }
  async write(content) {
    this.writes++;
    await new Promise(resolve => setTimeout(resolve, 1));
    if (this.fail) throw new Error('disk full');
    this.content = content;
  }
}

test('exact decimals normalize zero, exponents, signs and HALF_UP ties', () => {
  for (const value of ['0.00', '-0.000', '0e-50']) assert.equal(D.parse(value).toString(), '0');
  assert.equal(D.parse(' +1.2500e2 ').toString(), '125');
  assert.equal(D.parse('.005').toString(), '0.005');
  assert.equal(D.parse('9007199254740993').add(D.parse('0.5')).whole().toString(), '9007199254740994');
  assert.equal(D.parse('-1.5').whole().toString(), '-2');
  assert.equal(D.parse('-0.499').whole().toString(), '0');
  assert.equal(D.parse('0.1').add(D.parse('0.2')).toString(), '0.3');
  for (const value of ['', 'NaN', 'Infinity', '1,000', '12x', '1e1001']) assert.throws(() => D.parse(value));
});

// Independent fixed-point BigInt oracle. Decimal implementation does not use BigInt.
test('1200 deterministic arithmetic cases agree with BigInt fixed-point oracle', () => {
  let seed = 19;
  const random = () => (seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0);
  const format = (n, scale) => {
    const negative = n < 0n;
    let value = (negative ? -n : n).toString().padStart(scale + 1, '0');
    if (scale) value = value.slice(0, -scale) + '.' + value.slice(-scale);
    return (negative ? '-' : '') + value;
  };
  const rounded = (n, scale) => {
    const negative = n < 0n;
    const abs = negative ? -n : n;
    const divisor = 10n ** BigInt(scale);
    const value = abs / divisor + ((abs % divisor) * 2n >= divisor ? 1n : 0n);
    return (negative && value !== 0n ? '-' : '') + value;
  };
  for (let i = 0; i < 1200; i++) {
    const a = BigInt(random()) * BigInt(random()) * (random() % 2 ? -1n : 1n);
    const b = BigInt(random()) * (random() % 2 ? -1n : 1n);
    const sa = random() % 7, sb = random() % 7, scale = Math.max(sa, sb);
    const da = D.parse(format(a, sa)), db = D.parse(format(b, sb));
    const aa = a * 10n ** BigInt(scale - sa), bb = b * 10n ** BigInt(scale - sb);
    assert.equal(da.add(db).whole().toString(), rounded(aa + bb, scale));
    assert.equal(da.subtract(db).whole().toString(), rounded(aa - bb, scale));
    assert.equal(da.multiply(db).whole().toString(), rounded(a * b, sa + sb));
    assert.equal(Math.sign(da.compare(db)), aa === bb ? 0 : aa > bb ? 1 : -1);
  }
});

test('Android reference: default fees, room rates, integer rounding and billing date', () => {
  const b = bill();
  assert.equal(b.waterAmount, '10'); assert.equal(b.electricityAmount, '174'); assert.equal(b.total, '834');
  assert.equal(b.createdDate, '2026-08-01');
  const custom = bill(room({ rent: '500', customWaterRate: '6.00', customElectricityRate: '1.25' }),
    settings(), draft({ previousWater: '100', currentWater: '103', previousElectricity: '200', currentElectricity: '210' }));
  assert.equal(custom.waterRate, '6'); assert.equal(custom.electricityRate, '1.25'); assert.equal(custom.total, '531');
});

test('fees use unrounded usage, then round each fee separately', () => {
  const b = bill(room({ rent: '0' }), settings({ defaultWaterRate: '5', defaultElectricityRate: '1.3' }),
    draft({ previousWater: '1', currentWater: '1.1', previousElectricity: '1', currentElectricity: '1.1' }));
  assert.equal(b.waterUsage, '0'); assert.equal(b.waterAmount, '1'); assert.equal(b.total, '1');
});

test('first rent stores move-in readings and omits all usage-based fees', () => {
  const b = bill(room({ rent: '700' }), settings({ defaultManagementRate: '0.2' }),
    draft({ rentOnly: true, previousWater: '', previousElectricity: '', currentWater: '321', currentElectricity: '4567' }));
  assert.equal(b.previousWater, '321'); assert.equal(b.previousElectricity, '4567');
  assert.equal(b.managementAmount, '0'); assert.equal(b.waterAmount, '0'); assert.equal(b.total, '700');
});

test('rollover and replacement usage drive electricity and management fees', () => {
  const d = draft({ previousWater: '1', currentWater: '1', previousElectricity: '9900', currentElectricity: '100' });
  assert.equal(bill(room({ rent: '500' }), settings({ defaultManagementRate: '0.2' }), d).managementAmount, '40');
  d.electricityUsageOverride = '50';
  const b = bill(room({ rent: '500' }), settings({ defaultManagementRate: '0.2' }), d);
  assert.equal(b.electricityUsage, '50'); assert.equal(b.managementAmount, '10');
  assert.throws(() => bill(room(), settings(), draft({ previousWater: '515', currentWater: '513' })), /归零上限/);
});

test('room management overrides building; zero disables fee; blanks omit it', () => {
  const d = draft({ previousWater: '1', currentWater: '1', previousElectricity: '100', currentElectricity: '234' });
  const s = settings({ defaultElectricityRate: '0.7', defaultManagementRate: '0.2' });
  assert.equal(bill(room({ rent: '500', customManagementRate: '0.6' }), s, d).total, '674');
  assert.equal(bill(room({ customManagementRate: '0' }), s, d).managementAmount, '0');
  assert.equal(bill(room(), settings({ defaultManagementRate: ' ' }), d).managementRate, undefined);
});

test('rejects missing fields, invalid numbers, negative charges/rates/rent and override', () => {
  for (const d of [draft({ currentWater: '' }), draft({ currentWater: 'bad' }), draft({ waterUsageOverride: '-1' }),
    draft({ customCharges: [{ name: ' ', amount: '1' }] }), draft({ customCharges: [{ name: '网费', amount: '-1' }] })]) {
    assert.throws(() => bill(room(), settings(), d));
  }
  assert.throws(() => bill(room({ rent: '-1' })), /房租/);
  assert.throws(() => bill(room(), settings({ defaultManagementRate: '-0.1' })), /公共服务费/);
  assert.throws(() => bill(room(), settings({ defaultWaterRate: '-1' })), /水电单价/);
  assert.throws(() => bill(room(), settings(), draft({ rentOnly: true, currentWater: '-1' })), /入住/);
  assert.throws(() => bill(room(), settings(), draft({ month: '2026-13' })), /月份/);
});

test('missed months cross year and entry always switches to normal utility billing', () => {
  assert.deepEqual(C.missingBillMonths('2025-11', '2026-02'), ['2025-12', '2026-01']);
  assert.deepEqual(C.missingBillMonths('2026-08', '2026-08'), []);
  assert.equal(C.shiftMonth('2026-01', -1), '2025-12');
  const first = draft({ rentOnly: true, customCharges: [{ name: '网费', amount: '30' }] });
  assert.equal(C.withMergedRent(first, '700', []).rentOnly, false);
  const merged = C.withMergedRent(first, '700', ['2026-02']);
  assert.equal(merged.rentOnly, false);
  assert.deepEqual(JSON.parse(JSON.stringify(merged.customCharges)), [{ name: '网费', amount: '30' }, { name: '补收房租·2026年2月', amount: '700' }]);
  assert.equal(C.withMergedRent(merged, '700', ['2026-02']).customCharges.length, 2);
  assert.equal(first.rentOnly, true);
});

test('fixed charges apply only to new bills; saved empty drafts win', () => {
  const r = room({ recurringCharges: [{ name: '网费', amount: '30' }] });
  assert.deepEqual(C.chargesForBill(r), r.recurringCharges);
  assert.deepEqual(C.chargesForBill(r, draft()), []);
  assert.deepEqual(C.chargesForBill(r, undefined, bill()), []);
  const charges = C.chargesForBill(r); charges[0].amount = '500';
  assert.equal(r.recurringCharges[0].amount, '30');
});

test('room number ordering places shops first and handles numbers beyond safe integers', () => {
  const values = ['A10', '102', '无编号', '铺2', '101', '9007199254740993', '9007199254740992'];
  assert.deepEqual(values.sort(M.compareRoomNumbers), ['铺2', 'A10', '101', '102', '9007199254740992', '9007199254740993', '无编号']);
});

test('snapshot round-trip keeps templates, settings, charges, deposits, bills and drafts', async () => {
  const storage = new Storage(), store = await RentStore.open(storage);
  const r = room({ customManagementRate: '0.25', recurringCharges: [{ name: '网费', amount: '30' }],
    depositStatus: M.DepositStatus.COLLECTED, depositAmount: '1300', depositCollectedDate: '2026-08-01' });
  await store.saveRoom(r); await store.saveDraft(r.buildingId, r.id, draft()); await store.saveBill(bill(r));
  const reopened = await RentStore.open(storage);
  assert.deepEqual(reopened.snapshot(), store.snapshot());
  assert.equal(reopened.snapshot().data.receiptTemplate.elements.length, 29);
  const copy = reopened.snapshot(); copy.data.rooms[0].rent = '1';
  assert.equal(reopened.snapshot().data.rooms[0].rent, '650');
});

test('parallel saves serialize without lost rooms or drafts', async () => {
  const storage = new Storage(), store = await RentStore.open(storage);
  await Promise.all(Array.from({ length: 20 }, (_, i) => store.saveRoom(room({ id: 'r' + i, number: String(i) }))));
  await Promise.all(Array.from({ length: 20 }, (_, i) => store.saveDraft(M.DEFAULT_BUILDING_ID, 'r' + i, draft())));
  assert.equal(store.snapshot().data.rooms.length, 20); assert.equal(store.snapshot().drafts.length, 20);
  assert.equal(decodeState(storage.content).drafts.length, 20);
});

test('failed write retains durable and in-memory state; retry succeeds; flush reports failure', async () => {
  const storage = new Storage(), store = await RentStore.open(storage);
  await store.saveRoom(room()); const original = storage.content;
  storage.fail = true;
  await assert.rejects(store.saveRoom(room({ rent: '999' })), /disk full/);
  await assert.rejects(store.flush(), /disk full/);
  assert.equal(storage.content, original); assert.equal(store.snapshot().data.rooms[0].rent, '650');
  storage.fail = false; await store.saveRoom(room({ rent: '999' })); await store.flush();
  assert.equal(store.snapshot().data.rooms[0].rent, '999');
});

test('corrupt, incomplete, duplicate and future snapshots never become empty data', async () => {
  const valid = new StoredState();
  const cases = ['', '{', 'null', '[]', '{"format":"rent-receipt-harmonyos-local","version":1}',
    JSON.stringify({ ...valid, version: 2 }), JSON.stringify({ ...valid, data: { ...valid.data, rooms: [null] } }),
    JSON.stringify({ ...valid, data: { ...valid.data, buildings: [valid.data.buildings[0], valid.data.buildings[0]] } })];
  for (const content of cases) {
    const storage = new Storage(); storage.content = content;
    await assert.rejects(RentStore.open(storage));
    assert.equal(storage.content, content); assert.equal(storage.writes, 0);
  }
});

test('billing edits preserve ID/payment; mark-month keeps original paid date', async () => {
  const store = await RentStore.open(new Storage()); await store.saveRoom(room()); await store.saveBill(bill());
  await store.setBillPaid('bill-1', true, '2026-08-05');
  await store.markMonthPaid(M.DEFAULT_BUILDING_ID, '2026-08', '2026-08-10');
  await store.saveBill({ ...bill(), id: 'replacement', total: '999' });
  const b = store.snapshot().data.bills[0];
  assert.equal(b.id, 'bill-1'); assert.equal(b.paid, true); assert.equal(b.paidDate, '2026-08-05'); assert.equal(b.total, '999');
  await store.setBillPaid('bill-1', false, '2026-08-10');
  assert.equal(store.snapshot().data.bills[0].paidDate, undefined);
});

test('deleting a building atomically removes associated data and allows all-empty state', async () => {
  const storage = new Storage(), store = await RentStore.open(storage);
  await store.saveRoom(room()); await store.saveDraft(M.DEFAULT_BUILDING_ID, 'room-101', draft()); await store.saveBill(bill());
  storage.fail = true;
  await assert.rejects(store.deleteBuilding(M.DEFAULT_BUILDING_ID));
  assert.equal(store.snapshot().data.buildings.length, 1); assert.equal(store.snapshot().drafts.length, 1);
  storage.fail = false; await store.deleteBuilding(M.DEFAULT_BUILDING_ID);
  const reopened = await RentStore.open(storage);
  for (const key of ['buildings', 'rooms', 'bills']) assert.equal(reopened.snapshot().data[key].length, 0);
  assert.equal(reopened.snapshot().drafts.length, 0);
  await reopened.saveBuilding(Object.assign(new M.Building(), { id: 'new', name: '新楼栋' }));
  assert.equal(reopened.snapshot().data.buildings[0].id, 'new');
});

test('deleting a room retains historical bills, removes its drafts and rejects duplicate room numbers', async () => {
  const store = await RentStore.open(new Storage());
  await store.saveRoom(room()); await store.saveBill(bill()); await store.saveDraft(M.DEFAULT_BUILDING_ID, 'room-101', draft());
  await assert.rejects(store.saveRoom(room({ id: 'duplicate' })), /相同房号/);
  await store.deleteRoom('room-101');
  assert.equal(store.snapshot().data.bills.length, 1); assert.equal(store.snapshot().drafts.length, 0);
});
