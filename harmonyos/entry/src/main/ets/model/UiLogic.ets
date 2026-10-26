import { AppData, Room, Bill, BillDraft, PricingSettings, DepositStatus, CustomCharge } from './Models';
import { Decimal } from './Decimal';
import { chargesForBill, missingBillMonths, validateMonth } from './BillCalculator';

export function today(): string {
  const date = new Date();
  return String(date.getFullYear()).padStart(4, '0') + '-' + String(date.getMonth() + 1).padStart(2, '0') +
    '-' + String(date.getDate()).padStart(2, '0');
}

export function currentMonth(): string { return today().slice(0, 7); }
export function monthTitle(month: string): string {
  return Number(month.slice(0, 4)) + ' 年 ' + Number(month.slice(5)) + ' 月';
}
export function optionalNumber(value: string): string | undefined { return value.trim() || undefined; }
export function cloneRoom(room: Room): Room { return JSON.parse(JSON.stringify(room)) as Room; }
export function cloneDraft(draft: BillDraft): BillDraft { return JSON.parse(JSON.stringify(draft)) as BillDraft; }

export function entryDraft(data: AppData, room: Room, month: string, saved?: BillDraft): BillDraft {
  validateMonth(month);
  if (saved) { const draft = cloneDraft(saved); draft.rentOnly = false; return draft; }
  const existing = data.bills.find((bill: Bill) => bill.roomId === room.id && bill.buildingId === room.buildingId && bill.month === month);
  const previous = data.bills.filter((bill: Bill) => bill.roomId === room.id && bill.buildingId === room.buildingId && bill.month < month)
    .sort((a: Bill, b: Bill) => a.month > b.month ? -1 : 1)[0];
  const draft = new BillDraft();
  draft.month = month;
  draft.previousWater = existing?.previousWater ?? previous?.currentWater ?? '';
  draft.previousElectricity = existing?.previousElectricity ?? previous?.currentElectricity ?? '';
  draft.currentWater = existing?.currentWater ?? '';
  draft.currentElectricity = existing?.currentElectricity ?? '';
  draft.rentOnly = false;
  draft.customCharges = chargesForBill(room, undefined, existing);
  return draft;
}

export function entryMissingMonths(data: AppData, room: Room, month: string): string[] {
  const previous = data.bills.filter((b: Bill) => b.buildingId === room.buildingId && b.roomId === room.id && b.month < month)
    .sort((a: Bill, b: Bill) => a.month > b.month ? -1 : 1)[0];
  return missingBillMonths(previous?.month, month);
}

// Both existing clients detect gaps at building/month level, then offer
// merging those rent months for every room in that building.
export function buildingMissingMonths(data: AppData, buildingId: string, month: string): string[] {
  if (data.bills.some((bill: Bill) => bill.buildingId === buildingId && bill.month === month)) { return []; }
  const previous = data.bills.filter((bill: Bill) => bill.buildingId === buildingId && bill.month < month)
    .sort((a: Bill, b: Bill) => a.month > b.month ? -1 : 1)[0];
  return missingBillMonths(previous?.month, month);
}

export class MonthSummary {
  expected: string = '0';
  received: string = '0';
  waterReceived: string = '0';
  electricityReceived: string = '0';
  paidCount: number = 0;
  billCount: number = 0;
  occupiedCount: number = 0;
  roomCount: number = 0;
}

export function monthSummary(data: AppData, buildingId: string, month: string): MonthSummary {
  const summary = new MonthSummary();
  const rooms = data.rooms.filter((room: Room) => room.buildingId === buildingId);
  summary.roomCount = rooms.length;
  summary.occupiedCount = rooms.filter((room: Room) => room.occupied).length;
  const bills = data.bills.filter((bill: Bill) => bill.buildingId === buildingId && bill.month === month);
  summary.billCount = bills.length;
  let expected = Decimal.zero();
  let received = Decimal.zero();
  let water = Decimal.zero();
  let electricity = Decimal.zero();
  bills.forEach((bill: Bill) => {
    expected = expected.add(Decimal.parse(bill.total));
    if (bill.paid) {
      summary.paidCount++;
      received = received.add(Decimal.parse(bill.total));
      water = water.add(Decimal.parse(bill.waterAmount));
      electricity = electricity.add(Decimal.parse(bill.electricityAmount));
    }
  });
  summary.expected = expected.toString();
  summary.received = received.toString();
  summary.waterReceived = water.toString();
  summary.electricityReceived = electricity.toString();
  return summary;
}

function validNumber(text: string, label: string, optional: boolean = false, positive: boolean = false): void {
  if (optional && !text.trim()) { return; }
  if (!text.trim()) { throw new Error('请填写' + label); }
  const value = Decimal.parse(text);
  if (value.compare(Decimal.zero()) < 0 || (positive && value.compare(Decimal.zero()) === 0)) {
    throw new Error(label + (positive ? '必须大于零' : '不能为负数'));
  }
}

export function validatePricing(value: PricingSettings): void {
  validNumber(value.defaultWaterRate, '默认水价');
  validNumber(value.defaultElectricityRate, '默认电价');
  validNumber(value.defaultManagementRate ?? '', '公共服务费单价', true);
  validNumber(value.defaultWaterMeterMax ?? '', '水表上限', true, true);
  validNumber(value.defaultElectricityMeterMax ?? '', '电表上限', true, true);
}

export function validateRoom(value: Room): void {
  if (!value.number.trim()) { throw new Error('请填写房号'); }
  validNumber(value.rent, '月租');
  validNumber(value.depositAmount, '押金');
  validNumber(value.customWaterRate ?? '', '自定义水价', true);
  validNumber(value.customElectricityRate ?? '', '自定义电价', true);
  validNumber(value.customManagementRate ?? '', '自定义公共服务费', true);
  validNumber(value.customWaterMeterMax ?? '', '水表上限', true, true);
  validNumber(value.customElectricityMeterMax ?? '', '电表上限', true, true);
  value.recurringCharges.forEach((charge: CustomCharge) => {
    if (!charge.name.trim()) { throw new Error('请填写固定收费项名称'); }
    validNumber(charge.amount, '固定收费金额');
  });
}

// User-confirmed Android behavior: record the day on each status transition.
export function changeDepositStatus(room: Room, status: DepositStatus, day: string): Room {
  const value = cloneRoom(room);
  if (value.depositStatus !== status) {
    value.depositStatus = status;
    if (status === DepositStatus.COLLECTED) { value.depositCollectedDate = day; }
    if (status === DepositStatus.REFUNDED) { value.depositRefundedDate = day; }
  }
  return value;
}
