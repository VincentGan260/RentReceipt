import { RentStore } from './RentStore';
import { LocalSnapshotStorage } from './LocalSnapshotStorage';
import { EntryWorkflow } from './EntryWorkflow';

export class StoreSession {
  static store?: RentStore;
  static error: string = '';
  static entries?: EntryWorkflow;

  static async open(filesDir: string): Promise<void> {
    if (StoreSession.store) { return; }
    try {
      StoreSession.store = await RentStore.open(new LocalSnapshotStorage(filesDir));
      StoreSession.entries = new EntryWorkflow(StoreSession.store);
      StoreSession.error = '';
    } catch (error) {
      StoreSession.error = '本地数据读取失败。原文件已保留，请勿卸载或清除应用数据。';
    }
  }
}
