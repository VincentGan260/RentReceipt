import { Bill, CustomCharge } from './Models';
import { Decimal } from './Decimal';
export function usage(bill: Bill, water: boolean): string {
  const saved = water ? bill.waterUsage : bill.electricityUsage;
  return saved || Decimal.parse(water ? bill.currentWater : bill.currentElectricity)
    .subtract(Decimal.parse(water ? bill.previousWater : bill.previousElectricity)).whole().toString();
}
export function rmbUpper(value: string): string {
  const n = Decimal.parse(value).whole().toString();
  if (n === '0') { return '零元整'; }
  if (n.startsWith('-') || n.length > 16) { return '人民币 ' + n + ' 元整'; }
  const digits = '零壹贰叁肆伍陆柒捌玖'; const units = ['','拾','佰','仟']; const sections = ['','万','亿','兆'];
  let result = ''; let group = 0; let zero = false;
  for (let end = n.length; end > 0; end -= 4) {
    const part = n.slice(Math.max(0,end-4),end); const amount = Number(part);
    if (!amount) { zero = !!result; group++; continue; }
    let text = ''; let pending = false;
    for (let i = 0; i < part.length; i++) {
      const d = Number(part[i]);
      if (d === 0) { pending = !!text; }
      else { text += (pending ? '零' : '') + digits.charAt(d) + units[part.length-i-1]; pending = false; }
    }
    result = text + sections[group] + ((zero || (amount < 1000 && !!result)) ? '零' : '') + result;
    zero = false; group++;
  }
  return result + '元整';
}
export function receiptCharges(b: Bill): CustomCharge[] {
  const extra: CustomCharge[] = [];
  if (b.managementRate !== undefined) { extra.push({name:'公共服务费',amount:b.managementAmount}); }
  return extra.concat(b.customCharges);
}
export function resolveReceipt(source: string, b: Bill, name: string): string {
  const keys = ['room','receiptNo','date','building','currentWater','previousWater','waterUsage','waterRate','waterAmount','currentElectricity','previousElectricity','electricityUsage','electricityRate','electricityAmount','rent','totalUpper','total'];
  const values = [b.roomNumber + '号（' + name + '）',b.month.replace('-','') + b.roomNumber,b.month.slice(0,4)+' 年 '+String(Number(b.month.slice(5)))+' 月 1 日',name,b.currentWater,b.previousWater,usage(b,true),b.waterRate,b.waterAmount,b.currentElectricity,b.previousElectricity,usage(b,false),b.electricityRate,b.electricityAmount,b.rent,rmbUpper(b.total),b.total];
  keys.forEach((key: string,i: number) => { source = source.split('{'+key+'}').join(values[i]); }); return source;
}
