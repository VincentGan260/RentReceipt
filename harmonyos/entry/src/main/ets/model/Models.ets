export const DEFAULT_BUILDING_ID: string = 'default-building';
export const MERGED_RENT_CHARGE_PREFIX: string = '补收房租·';

export class PricingSettings {
  defaultWaterRate: string = '5.00';
  defaultElectricityRate: string = '1.30';
  defaultWaterMeterMax?: string;
  defaultElectricityMeterMax?: string = '10000';
  defaultManagementRate?: string;
}

export class ReceiptTextElement {
  id: string = '';
  content: string = '';
  x: number = 0;
  y: number = 0;
  fontSize: number = 0;
  centered: boolean = false;
  color: string = 'body';
}

export class ReceiptTemplate { elements: ReceiptTextElement[] = defaultReceiptElements(); }

export class Building {
  id: string = '';
  name: string = '';
  settings: PricingSettings = new PricingSettings();
  receiptTemplate?: ReceiptTemplate;
}

export enum DepositStatus {
  NOT_COLLECTED = 'NOT_COLLECTED', COLLECTED = 'COLLECTED', REFUNDED = 'REFUNDED'
}

export class CustomCharge { name: string = ''; amount: string = ''; }

export class Room {
  id: string = '';
  number: string = '';
  rent: string = '';
  buildingId: string = DEFAULT_BUILDING_ID;
  customWaterRate?: string;
  customElectricityRate?: string;
  customManagementRate?: string;
  customWaterMeterMax?: string;
  customElectricityMeterMax?: string;
  occupied: boolean = false;
  depositAmount: string = '0';
  depositStatus: DepositStatus = DepositStatus.NOT_COLLECTED;
  depositCollectedDate?: string;
  depositRefundedDate?: string;
  recurringCharges: CustomCharge[] = [];
}

export class BillDraft {
  month: string = '';
  previousWater: string = '';
  currentWater: string = '';
  previousElectricity: string = '';
  currentElectricity: string = '';
  rentOnly: boolean = false;
  waterUsageOverride?: string;
  electricityUsageOverride?: string;
  customCharges: CustomCharge[] = [];
}

export class Bill {
  id: string = '';
  buildingId: string = DEFAULT_BUILDING_ID;
  roomId: string = '';
  roomNumber: string = '';
  month: string = '';
  createdDate: string = '';
  previousWater: string = '';
  currentWater: string = '';
  waterRate: string = '';
  waterAmount: string = '';
  previousElectricity: string = '';
  currentElectricity: string = '';
  electricityRate: string = '';
  electricityAmount: string = '';
  rent: string = '';
  total: string = '';
  rentOnly: boolean = false;
  paid: boolean = false;
  paidDate?: string;
  waterUsage: string = '';
  electricityUsage: string = '';
  customCharges: CustomCharge[] = [];
  managementRate?: string;
  managementAmount: string = '0';
}

export class AppData {
  buildings: Building[] = [];
  rooms: Room[] = [];
  bills: Bill[] = [];
  receiptTemplate: ReceiptTemplate = new ReceiptTemplate();
}

// IDs are supplied by the platform (UUID) or by test fixtures.
export function initialData(): AppData {
  const data = new AppData();
  const building = new Building();
  building.id = DEFAULT_BUILDING_ID;
  building.name = '默认楼栋';
  data.buildings = [building];
  return data;
}

export function compareRoomNumbers(a: string, b: string): number {
  const aShop = /^(铺|店)/.test(a.trim());
  const bShop = /^(铺|店)/.test(b.trim());
  if (aShop !== bShop) { return aShop ? -1 : 1; }
  const left = a.replace(/\D/g, '').replace(/^0+/, '') || (/[0-9]/.test(a) ? '0' : '');
  const right = b.replace(/\D/g, '').replace(/^0+/, '') || (/[0-9]/.test(b) ? '0' : '');
  if (!left && right) { return 1; }
  if (left && !right) { return -1; }
  if (left.length !== right.length) { return left.length - right.length; }
  if (left !== right) { return left < right ? -1 : 1; }
  return a === b ? 0 : (a < b ? -1 : 1);
}

export function defaultReceiptElements(): ReceiptTextElement[] {
  return [
    {"id": "title", "content": "公寓房租、水、电费（专用）收据", "x": 1754, "y": 125, "fontSize": 108, "centered": true, "color": "body"},
    {"id": "userLabel", "content": "用户名称：", "x": 95, "y": 245, "fontSize": 66, "centered": false, "color": "body"},
    {"id": "room", "content": "{room}", "x": 405, "y": 245, "fontSize": 148, "centered": false, "color": "blue"},
    {"id": "roomSuffix", "content": "号", "x": 700, "y": 245, "fontSize": 66, "centered": false, "color": "body"},
    {"id": "receiptNo", "content": "№  {receiptNo}", "x": 2760, "y": 150, "fontSize": 76, "centered": false, "color": "red"},
    {"id": "date", "content": "{date}", "x": 2700, "y": 265, "fontSize": 90, "centered": false, "color": "blue"},
    {"id": "headItem", "content": "项  目", "x": 337, "y": 435, "fontSize": 66, "centered": true, "color": "body"},
    {"id": "headCurrent", "content": "本  月", "x": 777, "y": 435, "fontSize": 66, "centered": true, "color": "body"},
    {"id": "headPrevious", "content": "上  月", "x": 1172, "y": 435, "fontSize": 66, "centered": true, "color": "body"},
    {"id": "headUsage", "content": "实  用", "x": 1567, "y": 435, "fontSize": 66, "centered": true, "color": "body"},
    {"id": "headRate", "content": "单  价", "x": 2300, "y": 435, "fontSize": 66, "centered": true, "color": "body"},
    {"id": "waterRate", "content": "{waterRate}", "x": 2300, "y": 720, "fontSize": 136, "centered": true, "color": "blue"},
    {"id": "electricRate", "content": "{electricityRate}", "x": 2300, "y": 1020, "fontSize": 136, "centered": true, "color": "blue"},
    {"id": "headAmount", "content": "金      额", "x": 2799, "y": 435, "fontSize": 66, "centered": true, "color": "body"},
    {"id": "waterLabel", "content": "水费（立方米）", "x": 337, "y": 700, "fontSize": 66, "centered": true, "color": "body"},
    {"id": "waterCurrent", "content": "{currentWater}", "x": 777, "y": 720, "fontSize": 136, "centered": true, "color": "blue"},
    {"id": "waterPrevious", "content": "{previousWater}", "x": 1172, "y": 720, "fontSize": 136, "centered": true, "color": "blue"},
    {"id": "waterUsage", "content": "{waterUsage}", "x": 1567, "y": 720, "fontSize": 136, "centered": true, "color": "blue"},
    {"id": "waterAmount", "content": "{waterAmount}", "x": 2799, "y": 725, "fontSize": 136, "centered": true, "color": "blue"},
    {"id": "electricLabel", "content": "电费（度）", "x": 337, "y": 1000, "fontSize": 66, "centered": true, "color": "body"},
    {"id": "electricCurrent", "content": "{currentElectricity}", "x": 777, "y": 1020, "fontSize": 136, "centered": true, "color": "blue"},
    {"id": "electricPrevious", "content": "{previousElectricity}", "x": 1172, "y": 1020, "fontSize": 136, "centered": true, "color": "blue"},
    {"id": "electricUsage", "content": "{electricityUsage}", "x": 1567, "y": 1020, "fontSize": 136, "centered": true, "color": "blue"},
    {"id": "electricAmount", "content": "{electricityAmount}", "x": 2799, "y": 1025, "fontSize": 136, "centered": true, "color": "blue"},
    {"id": "rentLabel", "content": "房  租", "x": 337, "y": 1300, "fontSize": 66, "centered": true, "color": "body"},
    {"id": "rentAmount", "content": "{rent}", "x": 2799, "y": 1325, "fontSize": 136, "centered": true, "color": "blue"},
    {"id": "totalLabel", "content": "合  计（大写）", "x": 155, "y": 1635, "fontSize": 64, "centered": false, "color": "body"},
    {"id": "totalUpper", "content": "{totalUpper}", "x": 720, "y": 1695, "fontSize": 140, "centered": false, "color": "blue"},
    {"id": "total", "content": "¥ {total}", "x": 2720, "y": 1705, "fontSize": 168, "centered": false, "color": "blue"}
  ];
}
