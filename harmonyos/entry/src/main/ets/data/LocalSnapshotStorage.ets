import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { SnapshotStorage } from './RentStore';

// One snapshot includes business data and drafts, preventing partial cascaded deletes.
// Temporary file and target live in the same app-private directory.
export class LocalSnapshotStorage implements SnapshotStorage {
  private path: string;

  constructor(filesDir: string) { this.path = filesDir + '/rent-receipt-state.json'; }

  async read(): Promise<string | undefined> {
    try {
      if (!fs.accessSync(this.path)) { return undefined; }
      return await fs.readText(this.path);
    } catch {
      throw new Error('本地数据读取失败；原文件已保留');
    }
  }

  async write(content: string): Promise<void> {
    try {
      const temporary = this.path + '.tmp';
      const bytes = new util.TextEncoder().encodeInto(content);
      const file = await fs.open(temporary, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      try {
        const written = await fs.write(file.fd, bytes.buffer);
        if (written !== bytes.byteLength) { throw new Error('数据写入不完整'); }
        await fs.fsync(file.fd);
      } finally {
        await fs.close(file);
      }
      await fs.rename(temporary, this.path);
    } catch {
      throw new Error('本地数据保存失败；原文件已保留，请重试');
    }
  }
}
