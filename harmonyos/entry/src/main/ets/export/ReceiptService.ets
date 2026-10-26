import { common } from '@kit.AbilityKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { systemShare } from '@kit.ShareKit';
import { util } from '@kit.ArkTS';
import { Bill, Building, ReceiptTemplate } from '../model/Models';
import { receiptCharges } from '../model/ReceiptContent';
import { renderReceipt } from './ReceiptRenderer';

export function safeName(s: string): string { return s.replace(/[\\/:*?"'`<>|{}\[\]\u0000-\u001f]/g,'_').slice(0,100); }
export async function receiptPng(context: common.UIAbilityContext, b: Bill, building: Building, template?: ReceiptTemplate): Promise<string> {
  const renderer = renderReceipt(b,building.name,template ?? building.receiptTemplate ?? new ReceiptTemplate());
  const pixels = renderer.getPixelMap(0,0,3508,1970+receiptCharges(b).length*300);
  const packer = image.createImagePacker();
  const path = context.cacheDir + '/' + safeName(b.month+'-'+b.roomNumber+'房-'+util.generateRandomUUID())+'.png';
  try {
    const bytes = await packer.packing(pixels,{format:'image/png',quality:100});
    const f = await fs.open(path,fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
    try { if (await fs.write(f.fd,bytes) !== bytes.byteLength) { throw new Error('收据写入不完整'); } } finally { await fs.close(f); }
  } catch (e) {
    try { await fs.unlink(path); } catch {}
    throw new Error((e as Error).message);
  } finally { await packer.release(); await pixels.release(); }
  return path;
}
export async function saveReceiptImages(context: common.UIAbilityContext, paths: string[]): Promise<number> {
  const helper = photoAccessHelper.getPhotoAccessHelper(context); let saved = 0;
  try {
    for (let start = 0; start < paths.length; start += 100) {
      const group = paths.slice(start,start+100);
      const configs = group.map((p: string): photoAccessHelper.PhotoCreationConfig => { return {title:safeName(p.slice(p.lastIndexOf('/')+1,-4)),fileNameExtension:'png',photoType:photoAccessHelper.PhotoType.IMAGE}; });
      const uris = await helper.showAssetsCreationDialog(group.map((p: string) => fileUri.getUriFromPath(p)),configs);
      if (!uris.length) { return saved; }
      for (let i = 0; i < uris.length; i++) {
        const source = await fs.open(group[i],fs.OpenMode.READ_ONLY);
        try {
          const destination = await fs.open(uris[i],fs.OpenMode.WRITE_ONLY);
          try { await fs.copyFile(source.fd,destination.fd); saved++; } finally { await fs.close(destination); }
        } finally { await fs.close(source); }
      }
    }
    return saved;
  } catch (e) { throw new Error('已保存 '+saved+' 张；其余保存未完成：'+(e as Error).message); }
  finally { await helper.release(); }
}
export async function shareReceipt(context: common.UIAbilityContext, path: string): Promise<void> {
  const data = new systemShare.SharedData({utd:'general.png',uri:fileUri.getUriFromPath(path),title:'房租单'});
  await new systemShare.ShareController(data).show(context,{});
}
