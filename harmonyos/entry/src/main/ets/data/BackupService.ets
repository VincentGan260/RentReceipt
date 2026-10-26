import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { zlib } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { AppData } from '../model/Models';
import { BackupFile, exportTables, importTables } from './BackupTables';
import { BACKUP_LIMIT, inspectZip, writeZip, ZipFile, ZipEntry, crc32 } from './BackupZip';
import { today } from '../model/UiLogic';

async function readBytes(path: string): Promise<Uint8Array> {
  const file = await fs.open(path, fs.OpenMode.READ_ONLY);
  try {
    const size = (await fs.stat(file.fd)).size;
    if (size > BACKUP_LIMIT) { throw new Error('备份超过 64 MB'); }
    const bytes = new Uint8Array(size); let offset = 0;
    while (offset < size) {
      const buffer = new ArrayBuffer(size-offset);
      const count = await fs.read(file.fd,buffer);
      if (count <= 0) { throw new Error('文件读取不完整'); }
      bytes.set(new Uint8Array(buffer,0,count),offset); offset += count;
    }
    return bytes;
  } finally { await fs.close(file); }
}
async function writeBytes(path: string, bytes: Uint8Array): Promise<void> {
  const file = await fs.open(path,fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
  try {
    if (await fs.write(file.fd,bytes.buffer) !== bytes.length) { throw new Error('文件写入不完整'); }
    await fs.fsync(file.fd);
  } finally { await fs.close(file); }
}
export class BackupService {
  static async save(context: common.UIAbilityContext, data: AppData): Promise<boolean> {
    const encoder = new util.TextEncoder();
    const files = exportTables(data).map((f: BackupFile): ZipFile => { return {name:f.name,bytes:encoder.encodeInto(f.text)}; });
    const bytes = writeZip(files);
    const options = new picker.DocumentSaveOptions(); options.newFileNames = ['房租数据备份_' + today() + '.zip'];
    options.fileSuffixChoices = ['ZIP 备份|.zip'];
    const uris = await new picker.DocumentViewPicker(context).save(options);
    if (!uris.length) { return false; }
    await writeBytes(uris[0],bytes); return true;
  }
  static async select(context: common.UIAbilityContext): Promise<AppData | undefined> {
    const options = new picker.DocumentSelectOptions(); options.maxSelectNumber = 1;
    options.fileSuffixFilters = ['ZIP 备份|.zip'];
    const uris = await new picker.DocumentViewPicker(context).select(options);
    if (!uris.length) { return undefined; }
    const bytes = await readBytes(uris[0]); const entries = inspectZip(bytes);
    const directory = context.cacheDir + '/restore-' + util.generateRandomUUID();
    const archive = directory + '.zip'; await fs.mkdir(directory);
    try {
      await writeBytes(archive,bytes);
      await zlib.decompressFile(archive,directory,{});
      const files: BackupFile[] = [];
      for (const entry of entries) {
        const content = await readBytes(directory + '/' + entry.name);
        if (content.length !== entry.size || crc32(content) !== entry.checksum) { throw new Error('备份校验失败'); }
        files.push({name:entry.name,text:util.TextDecoder.create('utf-8', { fatal:true }).decodeToString(content)});
      }
      return importTables(files);
    } finally {
      try { await fs.rmdir(directory); } catch {}
      try { await fs.unlink(archive); } catch {}
    }
  }
}
