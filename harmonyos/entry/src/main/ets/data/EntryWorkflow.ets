import { Room, Bill, BillDraft, PricingSettings, AppData } from '../model/Models';
import { entryDraft, cloneDraft } from '../model/UiLogic';
import { createBill, withMergedRent } from '../model/BillCalculator';
import { RentStore } from './RentStore';

export class EntryState {
  buildingId: string = '';
  roomId: string = '';
  month: string = '';
  draft: BillDraft = new BillDraft();
  message: string = '修改后自动保存';
  sequence: number = 0;
}

// Retain the latest input across remounts while disk writes are still queued.
// Unsaved failures remain visible and retryable rather than being replaced by old data.
export class EntryWorkflow {
  private store: RentStore;
  private entries: EntryState[] = [];

  constructor(store: RentStore) { this.store = store; }

  state(room: Room, month: string): EntryState {
    let entry = this.entries.find((value: EntryState) => value.roomId === room.id &&
      value.buildingId === room.buildingId && value.month === month);
    if (!entry) {
      entry = new EntryState(); entry.buildingId = room.buildingId; entry.roomId = room.id; entry.month = month;
      entry.draft = entryDraft(this.store.snapshot().data, room, month, this.store.draft(room.buildingId, room.id, month));
      this.entries.push(entry);
    }
    return entry;
  }

  refreshRepriced(bills: Bill[]): void {
    bills.forEach((bill: Bill) => {
      const entry = this.entries.find((value: EntryState) => value.buildingId === bill.buildingId && value.roomId === bill.roomId && value.month === bill.month);
      if (entry) { entry.draft.customCharges = bill.customCharges; }
    });
  }

  prune(data: AppData): void {
    this.entries = this.entries.filter((entry: EntryState) => data.rooms.some((room: Room) =>
      room.id === entry.roomId && room.buildingId === entry.buildingId));
  }

  async mergeBuildingRent(buildingId: string, month: string, months: string[], newId: () => string): Promise<void> {
    const data = this.store.snapshot().data;
    const building = data.buildings.find((value) => value.id === buildingId);
    if (!building) { throw new Error('楼栋不存在'); }
    const rooms = data.rooms.filter((room: Room) => room.buildingId === buildingId);
    const errors = await Promise.all(rooms.map((room: Room): Promise<string> => {
      const draft = withMergedRent(this.state(room, month).draft, room.rent, months);
      return this.update(room, building.settings, draft, newId()).then(() => '', (error: Error) => error.message);
    }));
    const error = errors.find((value: string) => value !== '');
    if (error) { throw new Error(error); }
  }

  async update(room: Room, settings: PricingSettings, draft: BillDraft, id: string): Promise<void> {
    const entry = this.state(room, draft.month);
    const value = cloneDraft(draft);
    value.rentOnly = false;
    entry.draft = value;
    const sequence = ++entry.sequence;
    entry.message = '正在保存…';
    let bill: Bill | undefined;
    let reason = '';
    try { bill = createBill(room, settings, value, id); }
    catch (error) { reason = (error as Error).message; }
    try {
      await this.store.saveEntry(room.buildingId, room.id, value, bill);
      if (sequence === entry.sequence) { entry.message = bill ? '已自动出账 · ¥ ' + bill.total : '草稿已保存；' + reason; }
    } catch (error) {
      if (sequence === entry.sequence) { entry.message = '未保存：' + (error as Error).message + '。请重试。'; }
      throw new Error((error as Error).message);
    }
  }
}
