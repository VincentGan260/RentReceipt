const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript');
require.extensions['.ets'] = (module, filename) => {
  module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 }
  }).outputText, filename);
};
const root = path.resolve(__dirname, '../entry/src/main/ets');
const M = require(root + '/model/Models.ets');
const C = require(root + '/model/BillCalculator.ets');
const U = require(root + '/model/UiLogic.ets');
const { RentStore } = require(root + '/data/RentStore.ets');
const { EntryWorkflow } = require(root + '/data/EntryWorkflow.ets');
class Storage {
  content;
  fail = false;
  async read() { return this.content; }
  async write(content) {
    await new Promise(resolve => setTimeout(resolve, 2));
    if (this.fail) throw new Error('disk full');
    this.content = content;
  }
}
const room = (overrides = {}) => Object.assign(new M.Room(), { id: 'r1', number: '101', rent: '650', occupied: true }, overrides);
const draft = (overrides = {}) => Object.assign(new M.BillDraft(), {
  month: '2026-08', previousWater: '100', currentWater: '102', previousElectricity: '1000', currentElectricity: '1100'
}, overrides);

test('entry seeding prioritizes saved draft, then existing bill, then previous reading and recurring charges', () => {
  const data = M.initialData(), r = room({ recurringCharges: [{ name: '网费', amount: '30' }] });
  const prior = C.createBill(r, new M.PricingSettings(), draft({ month: '2026-07' }), 'prior'); data.bills = [prior];
  const newMonth = U.entryDraft(data, r, '2026-08');
  assert.equal(newMonth.previousWater, '102'); assert.equal(newMonth.currentWater, '');
  assert.deepEqual(newMonth.customCharges, r.recurringCharges);
  const existing = C.createBill(r, new M.PricingSettings(), draft({ customCharges: [] }), 'existing'); data.bills.push(existing);
  assert.deepEqual(U.entryDraft(data, r, '2026-08').customCharges, []);
  const saved = draft({ currentWater: '', previousWater: '999', customCharges: [] });
  assert.equal(U.entryDraft(data, r, '2026-08', saved).previousWater, '999');
  assert.equal(U.entryDraft(data, r, '2026-08', saved).currentWater, '');
  assert.equal(U.entryDraft(data, r, '2026-08', draft({ rentOnly: true })).rentOnly, false);
});

test('entry edits of legacy rent-only bills generate normal utilities without rewriting history', async () => {
  const store = await RentStore.open(new Storage()), r = room(), prices = new M.PricingSettings();
  await store.saveRoom(r);
  const old = C.createBill(r, prices, draft({ rentOnly: true }), 'old');
  await store.saveBill(old);
  const workflow = new EntryWorkflow(store);
  assert.equal(workflow.state(r, '2026-08').draft.rentOnly, false);
  assert.equal(store.snapshot().data.bills[0].rentOnly, true);
  await workflow.update(r, prices, draft({ rentOnly: true }), 'replacement');
  const bill = store.snapshot().data.bills[0];
  assert.equal(bill.id, 'old'); assert.equal(bill.rentOnly, false);
  assert.equal(bill.waterAmount, '10'); assert.equal(bill.electricityAmount, '130');
  assert.equal(bill.total, '790');
});

test('overview statistics are exact and isolated by building/month; dates follow confirmed deposit transitions', () => {
  const data = M.initialData(); data.rooms = [room(), room({ id: 'r2', number: '102', occupied: false })];
  const b = C.createBill(room(), new M.PricingSettings(), draft(), 'b'); b.paid = true;
  data.bills = [b, { ...b, id: 'other', buildingId: 'other', total: '9999' }, { ...b, id: 'past', month: '2026-07' }];
  const summary = U.monthSummary(data, M.DEFAULT_BUILDING_ID, '2026-08');
  assert.equal(summary.expected, '790'); assert.equal(summary.received, '790');
  assert.equal(summary.waterReceived, '10'); assert.equal(summary.electricityReceived, '130');
  assert.equal(summary.roomCount, 2); assert.equal(summary.occupiedCount, 1); assert.equal(summary.billCount, 1);
  let r = U.changeDepositStatus(room(), M.DepositStatus.COLLECTED, '2026-08-01');
  r = U.changeDepositStatus(r, M.DepositStatus.COLLECTED, '2026-08-02');
  assert.equal(r.depositCollectedDate, '2026-08-01');
  r = U.changeDepositStatus(r, M.DepositStatus.REFUNDED, '2026-08-03');
  r = U.changeDepositStatus(r, M.DepositStatus.COLLECTED, '2026-08-04');
  assert.equal(r.depositCollectedDate, '2026-08-04'); assert.equal(r.depositRefundedDate, '2026-08-03');
});

test('editor validation rejects invalid rates, meter caps and recurring charges before saving', () => {
  U.validatePricing(new M.PricingSettings()); U.validateRoom(room());
  assert.throws(() => U.validatePricing({ ...new M.PricingSettings(), defaultWaterRate: '' }));
  assert.throws(() => U.validatePricing({ ...new M.PricingSettings(), defaultElectricityMeterMax: '0' }));
  assert.throws(() => U.validateRoom(room({ customManagementRate: '-1' })));
  assert.throws(() => U.validateRoom(room({ recurringCharges: [{ name: '网费', amount: '' }] })));
  U.validateRoom(room({ customManagementRate: '0', customWaterMeterMax: undefined }));
});

test('rapid edits retain latest input during queued writes and do not overwrite another month', async () => {
  const storage = new Storage(), store = await RentStore.open(storage), r = room(), prices = new M.PricingSettings();
  await store.saveRoom(r); const workflow = new EntryWorkflow(store);
  const first = workflow.update(r, prices, draft({ currentWater: '103' }), 'b1');
  const latest = workflow.update(r, prices, draft({ currentWater: '104' }), 'b2');
  assert.equal(workflow.state(r, '2026-08').draft.currentWater, '104');
  const otherMonth = workflow.update(r, prices, draft({ month: '2026-09', currentWater: '105' }), 'b3');
  await Promise.all([first, latest, otherMonth]);
  assert.equal(store.draft(r.buildingId, r.id, '2026-08').currentWater, '104');
  assert.equal(store.draft(r.buildingId, r.id, '2026-09').currentWater, '105');
  assert.equal(store.snapshot().data.bills.find(b => b.month === '2026-08').waterAmount, '20');
  const reopened = await RentStore.open(storage);
  assert.equal(reopened.draft(r.buildingId, r.id, '2026-08').currentWater, '104');
});

test('failed entry save keeps input for retry and atomically retains both old bill and draft', async () => {
  const storage = new Storage(), store = await RentStore.open(storage), r = room(), prices = new M.PricingSettings();
  await store.saveRoom(r); const workflow = new EntryWorkflow(store);
  await workflow.update(r, prices, draft(), 'b1');
  await store.setBillPaid('b1', true, '2026-08-02');
  const original = storage.content;
  storage.fail = true;
  await assert.rejects(workflow.update(r, prices, draft({ currentWater: '104' }), 'b2'));
  assert.equal(storage.content, original); assert.equal(store.draft(r.buildingId, r.id, '2026-08').currentWater, '102');
  assert.equal(workflow.state(r, '2026-08').draft.currentWater, '104');
  assert.match(workflow.state(r, '2026-08').message, /未保存/);
  storage.fail = false;
  await workflow.update(r, prices, workflow.state(r, '2026-08').draft, 'b3');
  const bill = store.snapshot().data.bills[0];
  assert.equal(bill.id, 'b1'); assert.equal(bill.paidDate, '2026-08-02'); assert.equal(bill.waterAmount, '20');
});

test('incomplete input saves a draft without generating a bill; deletion cannot resurrect queued input', async () => {
  const store = await RentStore.open(new Storage()), r = room(), prices = new M.PricingSettings();
  await store.saveRoom(r); const workflow = new EntryWorkflow(store);
  await workflow.update(r, prices, draft({ currentWater: '' }), 'b1');
  assert.equal(store.snapshot().data.bills.length, 0); assert.match(workflow.state(r, '2026-08').message, /草稿已保存/);
  const deletion = store.deleteBuilding(r.buildingId);
  const late = workflow.update(r, prices, draft(), 'late');
  await deletion; await assert.rejects(late, /房间已不存在/);
  assert.equal(store.snapshot().drafts.length, 0); assert.equal(store.snapshot().data.bills.length, 0);
});

test('entry atomic API rejects a bill belonging to another month before touching storage', async () => {
  const storage = new Storage(), store = await RentStore.open(storage), r = room();
  await store.saveRoom(r); const original = storage.content;
  const wrong = C.createBill(r, new M.PricingSettings(), draft({ month: '2026-09' }), 'wrong');
  await assert.rejects(store.saveEntry(r.buildingId, r.id, draft(), wrong), /不一致/);
  assert.equal(storage.content, original); assert.equal(store.snapshot().drafts.length, 0);
});

test('missed rent detection matches both clients building-level semantics', () => {
  const data = M.initialData();
  const first = C.createBill(room(), new M.PricingSettings(), draft({ month: '2026-01' }), 'first');
  const second = C.createBill(room({ id: 'r2' }), new M.PricingSettings(), draft({ month: '2026-02' }), 'second');
  data.bills = [first, second, { ...second, id: 'other', buildingId: 'other', month: '2026-03' }];
  assert.deepEqual(U.buildingMissingMonths(data, M.DEFAULT_BUILDING_ID, '2026-04'), ['2026-03']);
  data.bills.push({ ...second, id: 'target', month: '2026-04' });
  assert.deepEqual(U.buildingMissingMonths(data, M.DEFAULT_BUILDING_ID, '2026-04'), []);
});

test('confirmed building merge updates every room, keeps manual charges and isolates other buildings', async () => {
  const storage = new Storage(), store = await RentStore.open(storage), prices = new M.PricingSettings();
  const a = room(), b = room({ id: 'r2', number: '102', rent: '700', recurringCharges: [{ name: '网费', amount: '30' }] });
  await store.saveRoom(a); await store.saveRoom(b);
  await store.saveBuilding(Object.assign(new M.Building(), { id: 'other', name: '其他楼栋' }));
  await store.saveRoom(room({ id: 'r3', buildingId: 'other' }));
  const workflow = new EntryWorkflow(store);
  await workflow.update(a, prices, draft({ month: '2026-12', customCharges: [{ name: '卫生费', amount: '10' }] }), 'a');
  let counter = 0;
  await workflow.mergeBuildingRent(M.DEFAULT_BUILDING_ID, '2026-12', ['2026-11'], () => 'merged-' + counter++);
  const state = store.snapshot();
  assert.equal(state.data.bills[0].total, '1450');
  assert.deepEqual(state.data.bills[0].customCharges, [
    { name: '卫生费', amount: '10' }, { name: '补收房租·2026年11月', amount: '650' }
  ]);
  assert.deepEqual(store.draft(b.buildingId, b.id, '2026-12').customCharges, [
    { name: '网费', amount: '30' }, { name: '补收房租·2026年11月', amount: '700' }
  ]);
  assert.equal(state.drafts.some(entry => entry.buildingId === 'other'), false);
  assert.equal(state.data.bills.length, 1); // Incomplete second room remains a draft.
});
