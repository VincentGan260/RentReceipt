import { Decimal } from './Decimal';
import { Bill, BillDraft, Room, PricingSettings, CustomCharge, MERGED_RENT_CHARGE_PREFIX } from './Models';

export class BillCalculation {
  waterUsage: string = '0';
  electricityUsage: string = '0';
  waterAmount: string = '0';
  electricityAmount: string = '0';
  managementAmount: string = '0';
  total: string = '0';
}

function requireCondition(condition: boolean, message: string): void {
  if (!condition) { throw new Error(message); }
}

function nonnegative(value: Decimal, message: string): void {
  requireCondition(value.compare(Decimal.zero()) >= 0, message);
}

function meterUsage(previous: Decimal, current: Decimal, maximum?: string,
  override?: string, label: string = '表具'): Decimal {
  if (override !== undefined && override.trim() !== '') {
    const actual = Decimal.parse(override);
    nonnegative(actual, label + '换表用量不能为负数');
    return actual;
  }
  if (current.compare(previous) >= 0) { return current.subtract(previous); }
  requireCondition(maximum !== undefined && maximum.trim() !== '',
    label + '读数变小，请设置归零上限或填写换表实际用量');
  const max = Decimal.parse(maximum!);
  requireCondition(max.compare(previous) > 0 && current.compare(Decimal.zero()) >= 0,
    label + '归零上限设置无效');
  return max.subtract(previous).add(current);
}

export function calculateBill(room: Room, settings: PricingSettings, draft: BillDraft): BillCalculation {
  let charges = Decimal.zero();
  draft.customCharges.forEach((charge: CustomCharge) => {
    requireCondition(charge.name.trim() !== '' && charge.amount.trim() !== '',
      '请填写其他收费项的名称和金额');
    const amount = Decimal.parse(charge.amount);
    nonnegative(amount, '其他收费项金额不能为负数');
    charges = charges.add(amount.whole());
  });
  const rent = Decimal.parse(room.rent);
  nonnegative(rent, '房租不能为负数');
  const result = new BillCalculation();
  if (draft.rentOnly) {
    requireCondition(draft.currentWater.trim() !== '' && draft.currentElectricity.trim() !== '',
      '请填写入住时的水电表读数');
    nonnegative(Decimal.parse(draft.currentWater), '入住时的水电表读数不能为负数');
    nonnegative(Decimal.parse(draft.currentElectricity), '入住时的水电表读数不能为负数');
    result.total = rent.add(charges).whole().toString();
    return result;
  }
  requireCondition([draft.previousWater, draft.currentWater, draft.previousElectricity, draft.currentElectricity]
    .every((value: string) => value.trim() !== ''), '请填写完整的本月和上月水电读数');
  const water = meterUsage(Decimal.parse(draft.previousWater), Decimal.parse(draft.currentWater),
    room.customWaterMeterMax ?? settings.defaultWaterMeterMax, draft.waterUsageOverride, '水表');
  const electricity = meterUsage(Decimal.parse(draft.previousElectricity), Decimal.parse(draft.currentElectricity),
    room.customElectricityMeterMax ?? settings.defaultElectricityMeterMax, draft.electricityUsageOverride, '电表');
  const waterRate = Decimal.parse(room.customWaterRate ?? settings.defaultWaterRate);
  const electricityRate = Decimal.parse(room.customElectricityRate ?? settings.defaultElectricityRate);
  nonnegative(waterRate, '水电单价不能为负数');
  nonnegative(electricityRate, '水电单价不能为负数');
  const managementText = room.customManagementRate ?? settings.defaultManagementRate;
  const managementRate = managementText?.trim() ? Decimal.parse(managementText) : Decimal.zero();
  nonnegative(managementRate, '公共服务费单价不能为负数');
  const waterAmount = water.multiply(waterRate).whole();
  const electricityAmount = electricity.multiply(electricityRate).whole();
  const managementAmount = electricity.multiply(managementRate).whole();
  result.waterUsage = water.whole().toString();
  result.electricityUsage = electricity.whole().toString();
  result.waterAmount = waterAmount.toString();
  result.electricityAmount = electricityAmount.toString();
  result.managementAmount = managementAmount.toString();
  result.total = rent.add(waterAmount).add(electricityAmount).add(managementAmount).add(charges).whole().toString();
  return result;
}

export function validateMonth(month: string): void {
  requireCondition(/^\d{4}-(0[1-9]|1[0-2])$/.test(month) && !month.startsWith('0000'), '月份格式错误');
}

export function shiftMonth(month: string, delta: number): string {
  validateMonth(month);
  requireCondition(Number.isInteger(delta), '月份偏移必须为整数');
  const index = Number(month.slice(0, 4)) * 12 + Number(month.slice(5)) - 1 + delta;
  const year = Math.floor(index / 12);
  requireCondition(year >= 1 && year <= 9999, '月份超出支持范围');
  return String(year).padStart(4, '0') + '-' + String(index % 12 + 1).padStart(2, '0');
}

export function createBill(room: Room, settings: PricingSettings, draft: BillDraft, id: string): Bill {
  validateMonth(draft.month);
  const value = calculateBill(room, settings, draft);
  const bill = new Bill();
  bill.id = id;
  bill.buildingId = room.buildingId;
  bill.roomId = room.id;
  bill.roomNumber = room.number;
  bill.month = draft.month;
  bill.createdDate = draft.month + '-01';
  bill.previousWater = Decimal.parse(draft.rentOnly ? draft.currentWater : draft.previousWater).whole().toString();
  bill.currentWater = Decimal.parse(draft.currentWater).whole().toString();
  bill.previousElectricity = Decimal.parse(draft.rentOnly ? draft.currentElectricity : draft.previousElectricity).whole().toString();
  bill.currentElectricity = Decimal.parse(draft.currentElectricity).whole().toString();
  bill.waterRate = Decimal.parse(room.customWaterRate ?? settings.defaultWaterRate).toString();
  bill.electricityRate = Decimal.parse(room.customElectricityRate ?? settings.defaultElectricityRate).toString();
  bill.waterUsage = value.waterUsage;
  bill.electricityUsage = value.electricityUsage;
  bill.waterAmount = value.waterAmount;
  bill.electricityAmount = value.electricityAmount;
  bill.managementAmount = value.managementAmount;
  const management = room.customManagementRate ?? settings.defaultManagementRate;
  bill.managementRate = management?.trim() ? Decimal.parse(management).toString() : undefined;
  bill.rent = Decimal.parse(room.rent).whole().toString();
  bill.total = value.total;
  bill.rentOnly = draft.rentOnly;
  bill.customCharges = draft.customCharges.map((charge: CustomCharge): CustomCharge => {
    const value = new CustomCharge();
    value.name = charge.name.trim();
    value.amount = Decimal.parse(charge.amount).whole().toString();
    return value;
  });
  return bill;
}

export function missingBillMonths(previous?: string, target: string = ''): string[] {
  if (!previous) { return []; }
  validateMonth(previous);
  validateMonth(target);
  const months: string[] = [];
  if (previous >= target) { return months; }
  let month = shiftMonth(previous, 1);
  while (month < target) { months.push(month); month = shiftMonth(month, 1); }
  return months;
}

// Entry always uses normal utility billing; historical rent-only bills remain readable.
export function withMergedRent(draft: BillDraft, rent: string, months: string[]): BillDraft {
  const result: BillDraft = JSON.parse(JSON.stringify(draft)) as BillDraft;
  result.customCharges = result.customCharges.filter((charge: CustomCharge) =>
    !charge.name.startsWith(MERGED_RENT_CHARGE_PREFIX));
  result.rentOnly = false;
  months.forEach((month: string) => {
    validateMonth(month);
    const charge = new CustomCharge();
    charge.name = MERGED_RENT_CHARGE_PREFIX + Number(month.slice(0, 4)) + '年' + Number(month.slice(5)) + '月';
    charge.amount = rent;
    result.customCharges.push(charge);
  });
  return result;
}

export function chargesForBill(room: Room, draft?: BillDraft, bill?: Bill): CustomCharge[] {
  const charges = draft ? draft.customCharges : (bill ? bill.customCharges : room.recurringCharges);
  return JSON.parse(JSON.stringify(charges)) as CustomCharge[];
}

export function billingFees(room: Room, settings: PricingSettings): string {
  const values = [room.rent, room.customWaterRate ?? settings.defaultWaterRate,
    room.customElectricityRate ?? settings.defaultElectricityRate,
    room.customManagementRate ?? settings.defaultManagementRate ?? '0'];
  return JSON.stringify(values.map((value: string) => Decimal.parse(value.trim() || '0').toString())) +
    JSON.stringify(room.recurringCharges.map((charge: CustomCharge) => [charge.name.trim(), Decimal.parse(charge.amount).toString()]));
}

export function repriceBill(bill: Bill, room: Room, settings: PricingSettings, previousRoom: Room): Bill {
  let charges = bill.customCharges.slice();
  if (billingCharges(previousRoom) !== billingCharges(room)) {
    previousRoom.recurringCharges.forEach((old: CustomCharge) => {
      const index = charges.findIndex((charge: CustomCharge) => charge.name === old.name.trim() &&
        Decimal.parse(charge.amount).compare(Decimal.parse(old.amount).whole()) === 0);
      if (index >= 0) { charges.splice(index, 1); }
    });
    charges = charges.concat(room.recurringCharges);
  }
  const draft = new BillDraft();
  draft.month = bill.month; draft.previousWater = bill.previousWater; draft.currentWater = bill.currentWater;
  draft.previousElectricity = bill.previousElectricity; draft.currentElectricity = bill.currentElectricity;
  draft.rentOnly = bill.rentOnly; draft.customCharges = charges;
  draft.waterUsageOverride = bill.waterUsage || Decimal.parse(bill.currentWater).subtract(Decimal.parse(bill.previousWater)).toString();
  draft.electricityUsageOverride = bill.electricityUsage || Decimal.parse(bill.currentElectricity).subtract(Decimal.parse(bill.previousElectricity)).toString();
  const result = createBill(room, settings, draft, bill.id);
  result.createdDate = bill.createdDate; result.paid = bill.paid; result.paidDate = bill.paidDate;
  return result;
}

function billingCharges(room: Room): string {
  return JSON.stringify(room.recurringCharges);
}
