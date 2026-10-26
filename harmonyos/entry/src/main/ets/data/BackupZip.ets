export const BACKUP_LIMIT: number = 64 * 1024 * 1024;
const NAMES: string[] = ['manifest.csv','settings.csv','buildings.csv','rooms.csv','bills.csv','receipt_templates.csv','room_charges.csv','bill_charges.csv'];
export class ZipEntry { name: string = ''; size: number = 0; checksum: number = 0; }
export class ZipFile { name: string = ''; bytes: Uint8Array = new Uint8Array(); }
export function crc32(bytes: Uint8Array): number {
  let crc = 0xFFFFFFFF;
  for (let i = 0; i < bytes.length; i++) { crc ^= bytes[i]; for (let b = 0; b < 8; b++) { crc = (crc >>> 1) ^ ((crc & 1) ? 0xEDB88320 : 0); } }
  return (crc ^ 0xFFFFFFFF) >>> 0;
}
function fail(): never { throw new Error('ZIP 文件损坏或包含不支持的内容'); }
function ascii(bytes: Uint8Array, offset: number, size: number): string {
  if (offset + size > bytes.length) { fail(); }
  let s = ''; for (let i = 0; i < size; i++) { s += String.fromCharCode(bytes[offset + i]); } return s;
}
// Preflight before native extraction, including local names: API 12 predates native traversal checks.
export function inspectZip(bytes: Uint8Array): ZipEntry[] {
  if (bytes.length < 22 || bytes.length > BACKUP_LIMIT) { fail(); }
  const v = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  let end = -1;
  for (let i = bytes.length - 22; i >= Math.max(0, bytes.length - 65557); i--) {
    if (v.getUint32(i,true) === 0x06054B50 && i + 22 + v.getUint16(i+20,true) === bytes.length) { end = i; break; }
  }
  if (end < 0 || v.getUint16(end+4,true) !== 0 || v.getUint16(end+6,true) !== 0) { fail(); }
  const count = v.getUint16(end+10,true); const start = v.getUint32(end+16,true);
  if (count < 1 || count > NAMES.length || count !== v.getUint16(end+8,true) || start + v.getUint32(end+12,true) !== end) { fail(); }
  const entries: ZipEntry[] = []; let p = start; let total = 0;
  for (let i = 0; i < count; i++) {
    if (p + 46 > end || v.getUint32(p,true) !== 0x02014B50) { fail(); }
    const flags = v.getUint16(p+8,true); const method = v.getUint16(p+10,true);
    const compressed = v.getUint32(p+20,true); const size = v.getUint32(p+24,true);
    const n = v.getUint16(p+28,true); const local = v.getUint32(p+42,true);
    const name = ascii(bytes,p+46,n);
    total += size;
    if (!NAMES.includes(name) || entries.some((e: ZipEntry) => e.name === name) || total > BACKUP_LIMIT ||
      (flags & ~0x080E) !== 0 || (method !== 0 && method !== 8) || v.getUint16(p+34,true) !== 0 ||
      ((v.getUint32(p+38,true) >>> 16) & 0xF000) === 0xA000 || local + 30 > start || v.getUint32(local,true) !== 0x04034B50) { fail(); }
    const ln = v.getUint16(local+26,true); const extra = v.getUint16(local+28,true);
    if (ascii(bytes,local+30,ln) !== name || v.getUint16(local+6,true) !== flags || v.getUint16(local+8,true) !== method ||
      local + 30 + ln + extra + compressed > start || (method === 0 && compressed !== size)) { fail(); }
    entries.push({name:name,size:size,checksum:v.getUint32(p+16,true)});
    p += 46 + n + v.getUint16(p+30,true) + v.getUint16(p+32,true);
  }
  if (p !== end) { fail(); } return entries;
}
export function writeZip(files: ZipFile[]): Uint8Array {
  let size = 22;
  files.forEach((f: ZipFile) => { size += 76 + f.name.length * 2 + f.bytes.length; });
  if (size > BACKUP_LIMIT) { throw new Error('备份超过 64 MB'); }
  const bytes = new Uint8Array(size); const v = new DataView(bytes.buffer); let p = 0; const offsets: number[] = [];
  files.forEach((f: ZipFile) => {
    offsets.push(p); v.setUint32(p,0x04034B50,true); v.setUint16(p+4,20,true); v.setUint16(p+6,0x0800,true);
    v.setUint32(p+14,crc32(f.bytes),true); v.setUint32(p+18,f.bytes.length,true); v.setUint32(p+22,f.bytes.length,true); v.setUint16(p+26,f.name.length,true);
    for (let i = 0; i < f.name.length; i++) { bytes[p+30+i] = f.name.charCodeAt(i); }
    bytes.set(f.bytes,p+30+f.name.length); p += 30 + f.name.length + f.bytes.length;
  });
  const central = p;
  files.forEach((f: ZipFile,i: number) => {
    v.setUint32(p,0x02014B50,true); v.setUint16(p+4,20,true); v.setUint16(p+6,20,true); v.setUint16(p+8,0x0800,true);
    v.setUint32(p+16,crc32(f.bytes),true); v.setUint32(p+20,f.bytes.length,true); v.setUint32(p+24,f.bytes.length,true); v.setUint16(p+28,f.name.length,true); v.setUint32(p+42,offsets[i],true);
    for (let j = 0; j < f.name.length; j++) { bytes[p+46+j] = f.name.charCodeAt(j); } p += 46 + f.name.length;
  });
  v.setUint32(p,0x06054B50,true); v.setUint16(p+8,files.length,true); v.setUint16(p+10,files.length,true); v.setUint32(p+12,p-central,true); v.setUint32(p+16,central,true);
  return bytes;
}
