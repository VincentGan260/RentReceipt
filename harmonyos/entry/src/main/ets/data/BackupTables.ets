import { AppData, Building, Room, Bill, CustomCharge, ReceiptTemplate, ReceiptTextElement, DepositStatus, DEFAULT_BUILDING_ID } from '../model/Models';
import { Decimal } from '../model/Decimal';
import { StoredState, decodeState } from './RentStore';

export class BackupFile { name: string = ''; text: string = ''; }
export function csv(rows: string[][]): string {
  return rows.map((row: string[]) => row.map((s: string) => '"' + s.replace(/"/g, '""') + '"').join(',')).join('\r\n') + '\r\n';
}
export function parseCsv(text: string): string[][] {
  const rows: string[][] = []; let row: string[] = []; let field = ''; let quoted = false; let closed = false;
  text = text.replace(/^\uFEFF/, '').replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"') { if (text[i + 1] === '"') { field += '"'; i++; } else { quoted = false; closed = true; } }
      else { field += c; }
    } else if (c === ',') { row.push(field); field = ''; closed = false; }
    else if (c === '\n') { row.push(field); rows.push(row); row = []; field = ''; closed = false; }
    else if (c === '"' && !field && !closed) { quoted = true; }
    else { if (closed || c === '"') { throw new Error('CSV 引号格式错误'); } field += c; }
  }
  if (quoted) { throw new Error('CSV 引号未闭合'); }
  if (field || row.length || closed) { row.push(field); rows.push(row); }
  if (!rows.length || new Set(rows[0]).size !== rows[0].length) { throw new Error('CSV 表头错误'); }
  return rows;
}
class CsvRow {
  values: Map<string, string> = new Map();
  constructor(headers: string[], values: string[]) {
    if (headers.length !== values.length) { throw new Error('CSV 列数错误'); }
    headers.forEach((key: string, i: number) => this.values.set(key, values[i]));
  }
  get(key: string): string { return this.values.get(key) ?? ''; }
  required(key: string): string { const s = this.get(key); if (!s.trim()) { throw new Error('备份缺少字段：' + key); } return s; }
  optional(key: string): string | undefined { return this.get(key) || undefined; }
  number(key: string, fallback?: string): string {
    const s = this.get(key) || fallback;
    if (s === undefined) { throw new Error('备份缺少金额：' + key); }
    Decimal.parse(s); return s;
  }
  optionalNumber(key: string): string | undefined { return this.get(key) ? this.number(key) : undefined; }
  bool(key: string, fallback: boolean = false): boolean {
    const s = this.get(key); if (!s) { return fallback; }
    if (s !== 'true' && s !== 'false') { throw new Error('备份状态格式错误：' + key); } return s === 'true';
  }
}
function table(files: BackupFile[], name: string, required: boolean = true): CsvRow[] {
  const file = files.find((f: BackupFile) => f.name === name);
  if (!file) { if (required) { throw new Error('备份缺少 ' + name); } return []; }
  const rows = parseCsv(file.text);
  return rows.slice(1).filter((r: string[]) => r.some((s: string) => !!s)).map((r: string[]) => new CsvRow(rows[0], r));
}
function file(name: string, rows: string[][]): BackupFile { return { name: name, text: csv(rows) }; }
function optional(value?: string): string { return value ?? ''; }
function templateRow(e: ReceiptTextElement, scope: string, id: string): string[] {
  return [scope, id, e.id, e.content, String(e.x), String(e.y), String(e.fontSize), String(e.centered), e.color];
}
export function exportTables(data: AppData): BackupFile[] {
  const templates: string[][] = [['scope','building_id','id','content','x','y','font_size','centered','color']];
  data.receiptTemplate.elements.forEach((e: ReceiptTextElement) => templates.push(templateRow(e, 'global', '')));
  data.buildings.forEach((b: Building) => b.receiptTemplate?.elements.forEach((e: ReceiptTextElement) => templates.push(templateRow(e, 'building', b.id))));
  const roomCharges: string[][] = [['room_id','item_index','name','amount']];
  const billCharges: string[][] = [['bill_id','item_index','name','amount']];
  data.rooms.forEach((r: Room) => r.recurringCharges.forEach((c: CustomCharge, i: number) => roomCharges.push([r.id,String(i),c.name,c.amount])));
  data.bills.forEach((b: Bill) => b.customCharges.forEach((c: CustomCharge, i: number) => billCharges.push([b.id,String(i),c.name,c.amount])));
  return [file('manifest.csv', [['format','version'],['rent-receipt','10']]),
    file('buildings.csv', [['id','name','default_water_rate','default_electricity_rate','default_water_meter_max','default_electricity_meter_max','default_management_rate'],
      ...data.buildings.map((b: Building) => [b.id,b.name,b.settings.defaultWaterRate,b.settings.defaultElectricityRate,optional(b.settings.defaultWaterMeterMax),optional(b.settings.defaultElectricityMeterMax),optional(b.settings.defaultManagementRate)])]),
    file('rooms.csv', [['id','building_id','number','rent','custom_water_rate','custom_electricity_rate','occupied','deposit_amount','deposit_status','deposit_collected_date','deposit_refunded_date','custom_water_meter_max','custom_electricity_meter_max','custom_management_rate'],
      ...data.rooms.map((r: Room) => [r.id,r.buildingId,r.number,r.rent,optional(r.customWaterRate),optional(r.customElectricityRate),String(r.occupied),r.depositAmount,r.depositStatus,optional(r.depositCollectedDate),optional(r.depositRefundedDate),optional(r.customWaterMeterMax),optional(r.customElectricityMeterMax),optional(r.customManagementRate)])]),
    file('bills.csv', [['id','building_id','room_id','room_number','month','created_date','previous_water','current_water','water_rate','water_amount','previous_electricity','current_electricity','electricity_rate','electricity_amount','rent','total','paid','paid_date','water_usage','electricity_usage','rent_only','management_rate','management_amount'],
      ...data.bills.map((b: Bill) => [b.id,b.buildingId,b.roomId,b.roomNumber,b.month,b.createdDate,b.previousWater,b.currentWater,b.waterRate,b.waterAmount,b.previousElectricity,b.currentElectricity,b.electricityRate,b.electricityAmount,b.rent,b.total,String(b.paid),optional(b.paidDate),b.waterUsage,b.electricityUsage,String(b.rentOnly),optional(b.managementRate),b.managementAmount])]),
    file('receipt_templates.csv', templates),file('room_charges.csv',roomCharges),file('bill_charges.csv',billCharges)];
}
function readTemplates(rows: CsvRow[]): ReceiptTemplate {
  const t = new ReceiptTemplate(); t.elements = rows.map((r: CsvRow): ReceiptTextElement => {
    const e = new ReceiptTextElement(); e.id = r.required('id'); e.content = r.get('content');
    e.x = Number(r.required('x')); e.y = Number(r.required('y')); e.fontSize = Number(r.required('font_size'));
    e.centered = r.bool('centered'); e.color = r.get('color') || 'body'; return e;
  }); return t;
}
function addCharges(rows: CsvRow[], ids: string[], key: string): Map<string, CustomCharge[]> {
  const result = new Map<string, CustomCharge[]>();
  rows.sort((a: CsvRow,b: CsvRow) => Number(a.get('item_index')) - Number(b.get('item_index')));
  rows.forEach((r: CsvRow) => {
    const id = r.required(key); const index = Number(r.required('item_index'));
    if (!ids.includes(id) || !Number.isInteger(index) || index < 0) { throw new Error('费用引用或顺序错误'); }
    const c = new CustomCharge(); c.name = r.required('name'); c.amount = r.number('amount');
    if (Decimal.parse(c.amount).compare(Decimal.zero()) < 0) { throw new Error('费用金额不能为负数'); }
    const list = result.get(id) ?? []; list.push(c); result.set(id,list);
  }); return result;
}
export function importTables(files: BackupFile[]): AppData {
  const manifest = table(files,'manifest.csv');
  const v = Number(manifest[0]?.get('version'));
  if (manifest.length !== 1 || manifest[0].get('format') !== 'rent-receipt' || !Number.isInteger(v) || v < 1 || v > 10) { throw new Error('备份格式或版本不受支持'); }
  const data = new AppData();
  if (v === 1) {
    const b = new Building(); b.id = DEFAULT_BUILDING_ID; b.name = '默认楼栋';
    const settings = table(files,'settings.csv');
    b.settings.defaultWaterRate = settings.find((r: CsvRow) => r.get('key') === 'default_water_rate')?.number('value') ?? '5';
    b.settings.defaultElectricityRate = settings.find((r: CsvRow) => r.get('key') === 'default_electricity_rate')?.number('value') ?? '1.3';
    data.buildings = [b];
  } else {
    data.buildings = table(files,'buildings.csv').map((r: CsvRow): Building => {
      const b = new Building(); b.id = r.required('id'); b.name = r.required('name');
      b.settings.defaultWaterRate = r.number('default_water_rate'); b.settings.defaultElectricityRate = r.number('default_electricity_rate');
      b.settings.defaultWaterMeterMax = v >= 6 ? r.optionalNumber('default_water_meter_max') : undefined;
      b.settings.defaultElectricityMeterMax = v >= 6 ? r.optionalNumber('default_electricity_meter_max') : '10000';
      b.settings.defaultManagementRate = v >= 9 ? r.optionalNumber('default_management_rate') : undefined; return b;
    });
    if (!data.buildings.length) { throw new Error('备份中没有楼栋'); }
  }
  data.rooms = table(files,'rooms.csv').map((r: CsvRow): Room => {
    const room = new Room(); room.id = r.required('id'); room.buildingId = v === 1 ? DEFAULT_BUILDING_ID : r.required('building_id');
    room.number = r.required('number'); room.rent = r.number('rent'); room.customWaterRate = r.optionalNumber('custom_water_rate'); room.customElectricityRate = r.optionalNumber('custom_electricity_rate');
    if (v >= 4) {
      room.occupied = r.bool('occupied'); room.depositAmount = r.number('deposit_amount','0');
      room.depositStatus = (r.get('deposit_status') || 'NOT_COLLECTED') as DepositStatus;
      room.depositCollectedDate = r.optional('deposit_collected_date'); room.depositRefundedDate = r.optional('deposit_refunded_date');
    }
    if (v >= 6) { room.customWaterMeterMax = r.optionalNumber('custom_water_meter_max'); room.customElectricityMeterMax = r.optionalNumber('custom_electricity_meter_max'); }
    if (v >= 10) { room.customManagementRate = r.optionalNumber('custom_management_rate'); } return room;
  });
  data.bills = table(files,'bills.csv').map((r: CsvRow): Bill => {
    const b = new Bill(); b.id = r.required('id'); b.buildingId = v === 1 ? DEFAULT_BUILDING_ID : r.required('building_id');
    b.roomId = r.required('room_id'); b.roomNumber = r.required('room_number'); b.month = r.required('month'); b.createdDate = r.required('created_date');
    b.previousWater = r.number('previous_water'); b.currentWater = r.number('current_water'); b.waterRate = r.number('water_rate'); b.waterAmount = r.number('water_amount');
    b.previousElectricity = r.number('previous_electricity'); b.currentElectricity = r.number('current_electricity'); b.electricityRate = r.number('electricity_rate'); b.electricityAmount = r.number('electricity_amount'); b.rent = r.number('rent'); b.total = r.number('total');
    if (v >= 4) { b.paid = r.bool('paid'); b.paidDate = r.optional('paid_date'); }
    b.waterUsage = v >= 6 ? r.get('water_usage') : '';
    b.electricityUsage = v >= 6 ? r.get('electricity_usage') : '';
    if (b.waterUsage) { Decimal.parse(b.waterUsage); }
    if (b.electricityUsage) { Decimal.parse(b.electricityUsage); }
    b.rentOnly = v >= 7 ? r.bool('rent_only') : false;
    if (v >= 9) { b.managementRate = r.optionalNumber('management_rate'); b.managementAmount = r.number('management_amount','0'); } return b;
  });
  if (v >= 10) {
    const charges = addCharges(table(files,'room_charges.csv'), data.rooms.map((r: Room) => r.id),'room_id');
    data.rooms.forEach((r: Room) => { r.recurringCharges = charges.get(r.id) ?? []; });
  }
  if (v >= 8) {
    const charges = addCharges(table(files,'bill_charges.csv'), data.bills.map((b: Bill) => b.id),'bill_id');
    data.bills.forEach((b: Bill) => { b.customCharges = charges.get(b.id) ?? []; });
  }
  if (v >= 3) {
    const templates = table(files,'receipt_templates.csv');
    const global = templates.filter((r: CsvRow) => r.get('scope') === 'global');
    if (global.length) { data.receiptTemplate = readTemplates(global); }
    data.buildings.forEach((b: Building) => {
      const own = templates.filter((r: CsvRow) => r.get('scope') === 'building' && r.get('building_id') === b.id);
      if (own.length) { b.receiptTemplate = readTemplates(own); }
    });
  }
  const state = new StoredState(); state.data = data;
  return decodeState(JSON.stringify(state)).data;
}
