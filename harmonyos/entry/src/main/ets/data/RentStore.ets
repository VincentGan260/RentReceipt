import { AppData, Building, Room, Bill, BillDraft, PricingSettings, CustomCharge,
  ReceiptTemplate, ReceiptTextElement, initialData, compareRoomNumbers, DepositStatus } from '../model/Models';
import { validateMonth } from '../model/BillCalculator';
import { Decimal } from '../model/Decimal';

export interface SnapshotStorage {
  read(): Promise<string | undefined>;
  write(content: string): Promise<void>;
}

export class StoredDraft {
  buildingId: string = '';
  roomId: string = '';
  draft: BillDraft = new BillDraft();
}

export class StoredState {
  format: string = 'rent-receipt-harmonyos-local';
  version: number = 1;
  data: AppData = initialData();
  drafts: StoredDraft[] = [];
}

function check(condition: boolean): void {
  if (!condition) { throw new Error('本地数据格式错误；原文件已保留'); }
}

function object(value: Object): boolean { return value !== null && typeof value === 'object' && !Array.isArray(value); }
function texts(values: string[]): void { check(values.every((value: string) => typeof value === 'string')); }
function optionalTexts(values: (string | undefined)[]): void {
  check(values.every((value: string | undefined) => value === undefined || typeof value === 'string'));
}
function charges(values: CustomCharge[]): void {
  check(Array.isArray(values));
  values.forEach((value: CustomCharge) => { check(object(value)); texts([value.name, value.amount]); });
}
function template(value: ReceiptTemplate): void {
  check(object(value) && Array.isArray(value.elements));
  value.elements.forEach((element: ReceiptTextElement) => {
    check(object(element));
    texts([element.id, element.content, element.color]);
    check([element.x, element.y, element.fontSize].every((v: number) => typeof v === 'number' && Number.isFinite(v)));
    check(typeof element.centered === 'boolean');
  });
}
function settings(value: PricingSettings): void {
  check(object(value));
  texts([value.defaultWaterRate, value.defaultElectricityRate]);
  optionalTexts([value.defaultWaterMeterMax, value.defaultElectricityMeterMax, value.defaultManagementRate]);
}
function validateData(data: AppData): void {
  check(object(data) && Array.isArray(data.buildings) && Array.isArray(data.rooms) && Array.isArray(data.bills));
  template(data.receiptTemplate);
  const buildingIds: string[] = [];
  data.buildings.forEach((value: Building) => {
    check(object(value)); texts([value.id, value.name]);
    check(value.id !== '' && !buildingIds.includes(value.id)); buildingIds.push(value.id);
    settings(value.settings);
    if (value.receiptTemplate !== undefined) { template(value.receiptTemplate); }
  });
  const roomIds: string[] = [];
  data.rooms.forEach((value: Room) => {
    check(object(value)); texts([value.id, value.number, value.rent, value.buildingId, value.depositAmount]);
    check(value.id !== '' && !roomIds.includes(value.id) && buildingIds.includes(value.buildingId));
    roomIds.push(value.id);
    optionalTexts([value.customWaterRate, value.customElectricityRate, value.customManagementRate,
      value.customWaterMeterMax, value.customElectricityMeterMax, value.depositCollectedDate, value.depositRefundedDate]);
    check(typeof value.occupied === 'boolean' && [DepositStatus.NOT_COLLECTED, DepositStatus.COLLECTED,
      DepositStatus.REFUNDED].includes(value.depositStatus));
    charges(value.recurringCharges);
  });
  const billIds: string[] = [];
  const billKeys: string[] = [];
  data.bills.forEach((value: Bill) => {
    check(object(value));
    texts([value.id, value.buildingId, value.roomId, value.roomNumber, value.month, value.createdDate,
      value.previousWater, value.currentWater, value.waterRate, value.waterAmount, value.previousElectricity,
      value.currentElectricity, value.electricityRate, value.electricityAmount, value.rent, value.total,
      value.waterUsage, value.electricityUsage, value.managementAmount]);
    optionalTexts([value.paidDate, value.managementRate]);
    const key = JSON.stringify([value.roomId, value.month]);
    check(value.id !== '' && !billIds.includes(value.id) && !billKeys.includes(key) && buildingIds.includes(value.buildingId));
    billIds.push(value.id); billKeys.push(key);
    validateMonth(value.month);
    check(typeof value.rentOnly === 'boolean' && typeof value.paid === 'boolean');
    charges(value.customCharges);
  });
}

export function decodeState(content: string): StoredState {
  const value = JSON.parse(content) as StoredState;
  check(object(value) && value.format === 'rent-receipt-harmonyos-local' && value.version === 1);
  validateData(value.data);
  check(Array.isArray(value.drafts));
  const keys: string[] = [];
  value.drafts.forEach((entry: StoredDraft) => {
    check(object(entry)); texts([entry.buildingId, entry.roomId]);
    check(value.data.rooms.some((room: Room) => room.id === entry.roomId && room.buildingId === entry.buildingId));
    const draft = entry.draft;
    check(object(draft));
    texts([draft.month, draft.previousWater, draft.currentWater, draft.previousElectricity, draft.currentElectricity]);
    optionalTexts([draft.waterUsageOverride, draft.electricityUsageOverride]);
    validateMonth(draft.month);
    check(typeof draft.rentOnly === 'boolean'); charges(draft.customCharges);
    const key = JSON.stringify([entry.buildingId, entry.roomId, draft.month]);
    check(!keys.includes(key)); keys.push(key);
  });
  return value;
}

function cloneState(value: StoredState): StoredState { return decodeState(JSON.stringify(value)); }

// Serialize mutations and publish state only after durable storage succeeds.
// No default-data fallback is allowed when an existing snapshot is corrupt.
export class RentStore {
  private state: StoredState;
  private storage: SnapshotStorage;
  private pending: Promise<void> = Promise.resolve();
  private lastError?: string;

  private constructor(storage: SnapshotStorage, state: StoredState) {
    this.storage = storage; this.state = state;
  }

  static async open(storage: SnapshotStorage): Promise<RentStore> {
    const content = await storage.read();
    return new RentStore(storage, content === undefined ? new StoredState() : decodeState(content));
  }

  snapshot(): StoredState { return cloneState(this.state); }

  private commit(change: (next: StoredState) => void): Promise<void> {
    const operation = this.pending.then(async () => {
      const next = cloneState(this.state);
      change(next);
      const content = JSON.stringify(next);
      decodeState(content);
      await this.storage.write(content);
      this.state = next;
      this.lastError = undefined;
    });
    this.pending = operation.catch((error: Error) => { this.lastError = error.message; });
    return operation;
  }

  flush(): Promise<void> {
    return this.pending.then(() => { if (this.lastError) { throw new Error(this.lastError); } });
  }

  saveTemplate(buildingId: string, value?: ReceiptTemplate): Promise<void> {
    const copy = value === undefined ? undefined : JSON.parse(JSON.stringify(value)) as ReceiptTemplate;
    return this.commit((next: StoredState) => {
      const building = next.data.buildings.find((b: Building) => b.id === buildingId);
      if (!building) { throw new Error('楼栋不存在'); }
      building.receiptTemplate = copy;
    });
  }

  restore(data: AppData): Promise<void> {
    const restored = new StoredState(); restored.data = data;
    const checked = decodeState(JSON.stringify(restored));
    return this.commit((next: StoredState) => { next.data = checked.data; next.drafts = []; });
  }

  saveBuilding(value: Building): Promise<void> {
    const building = JSON.parse(JSON.stringify(value)) as Building;
    if (!building.name.trim() || !building.id) { return Promise.reject(new Error('请填写楼栋名称')); }
    return this.commit((next: StoredState) => {
      const index = next.data.buildings.findIndex((b: Building) => b.id === building.id);
      if (index < 0) { next.data.buildings.push(building); } else { next.data.buildings[index] = building; }
    });
  }

  saveRoom(value: Room): Promise<void> {
    const room = JSON.parse(JSON.stringify(value)) as Room;
    if (!room.number.trim() || !room.id) { return Promise.reject(new Error('请填写房号')); }
    return this.commit((next: StoredState) => {
      if (next.data.rooms.some((r: Room) => r.id !== room.id && r.buildingId === room.buildingId && r.number === room.number)) {
        throw new Error('该楼栋已存在相同房号');
      }
      if (Decimal.parse(room.rent).compare(Decimal.zero()) < 0 || Decimal.parse(room.depositAmount).compare(Decimal.zero()) < 0) {
        throw new Error('房租和押金不能为负数');
      }
      const index = next.data.rooms.findIndex((r: Room) => r.id === room.id);
      if (index < 0) { next.data.rooms.push(room); } else { next.data.rooms[index] = room; }
      next.data.rooms.sort((a: Room, b: Room) => compareRoomNumbers(a.number, b.number));
    });
  }

  deleteRoom(id: string): Promise<void> {
    return this.commit((next: StoredState) => {
      next.data.rooms = next.data.rooms.filter((r: Room) => r.id !== id);
      next.drafts = next.drafts.filter((d: StoredDraft) => d.roomId !== id);
      // Both existing clients preserve historical bills when a room is deleted.
    });
  }

  deleteBuilding(id: string): Promise<void> {
    return this.commit((next: StoredState) => {
      const ids = next.data.rooms.filter((r: Room) => r.buildingId === id).map((r: Room) => r.id);
      next.data.buildings = next.data.buildings.filter((b: Building) => b.id !== id);
      next.data.rooms = next.data.rooms.filter((r: Room) => r.buildingId !== id);
      next.data.bills = next.data.bills.filter((b: Bill) => b.buildingId !== id && !ids.includes(b.roomId));
      next.drafts = next.drafts.filter((d: StoredDraft) => d.buildingId !== id && !ids.includes(d.roomId));
    });
  }

  saveDraft(buildingId: string, roomId: string, value: BillDraft): Promise<void> {
    const entry = new StoredDraft();
    entry.buildingId = buildingId; entry.roomId = roomId;
    entry.draft = JSON.parse(JSON.stringify(value)) as BillDraft;
    return this.commit((next: StoredState) => {
      const index = next.drafts.findIndex((d: StoredDraft) => d.buildingId === buildingId &&
        d.roomId === roomId && d.draft.month === entry.draft.month);
      if (index < 0) { next.drafts.push(entry); } else { next.drafts[index] = entry; }
    });
  }

  draft(buildingId: string, roomId: string, month: string): BillDraft | undefined {
    return this.snapshot().drafts.find((d: StoredDraft) => d.buildingId === buildingId &&
      d.roomId === roomId && d.draft.month === month)?.draft;
  }

  saveEntry(buildingId: string, roomId: string, value: BillDraft, result?: Bill): Promise<void> {
    const draft = JSON.parse(JSON.stringify(value)) as BillDraft;
    const bill = result ? JSON.parse(JSON.stringify(result)) as Bill : undefined;
    return this.commit((next: StoredState) => {
      if (!next.data.rooms.some((room: Room) => room.id === roomId && room.buildingId === buildingId)) {
        throw new Error('房间已不存在，录入未保存');
      }
      const entry = new StoredDraft();
      entry.buildingId = buildingId; entry.roomId = roomId; entry.draft = draft;
      const index = next.drafts.findIndex((d: StoredDraft) => d.buildingId === buildingId && d.roomId === roomId && d.draft.month === draft.month);
      if (index < 0) { next.drafts.push(entry); } else { next.drafts[index] = entry; }
      if (bill) {
        if (bill.roomId !== roomId || bill.buildingId !== buildingId || bill.month !== draft.month) {
          throw new Error('账单与录入房间或月份不一致');
        }
        const billIndex = next.data.bills.findIndex((b: Bill) => b.roomId === roomId && b.month === draft.month);
        if (billIndex < 0) { next.data.bills.push(bill); } else {
          const existing = next.data.bills[billIndex];
          bill.id = existing.id; bill.paid = existing.paid; bill.paidDate = existing.paidDate;
          next.data.bills[billIndex] = bill;
        }
        next.data.bills.sort((a: Bill, b: Bill) => a.month === b.month ? 0 : (a.month > b.month ? -1 : 1));
      }
    });
  }

  saveBill(value: Bill): Promise<void> {
    const bill = JSON.parse(JSON.stringify(value)) as Bill;
    return this.commit((next: StoredState) => {
      const index = next.data.bills.findIndex((b: Bill) => b.roomId === bill.roomId && b.month === bill.month);
      if (index < 0) { next.data.bills.push(bill); } else {
        const existing = next.data.bills[index];
        bill.id = existing.id; bill.paid = existing.paid; bill.paidDate = existing.paidDate;
        next.data.bills[index] = bill;
      }
      next.data.bills.sort((a: Bill, b: Bill) => a.month === b.month ? 0 : (a.month > b.month ? -1 : 1));
    });
  }

  setBillPaid(id: string, paid: boolean, date: string): Promise<void> {
    return this.commit((next: StoredState) => {
      const bill = next.data.bills.find((b: Bill) => b.id === id);
      if (!bill) { throw new Error('账单不存在'); }
      bill.paid = paid; bill.paidDate = paid ? date : undefined;
    });
  }

  markMonthPaid(buildingId: string, month: string, date: string, paid: boolean = true): Promise<void> {
    return this.commit((next: StoredState) => {
      validateMonth(month);
      next.data.bills.forEach((b: Bill) => {
        if (b.buildingId === buildingId && b.month === month && b.paid !== paid) {
          b.paid = paid; b.paidDate = paid ? date : undefined;
        }
      });
    });
  }
}
