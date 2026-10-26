import { LengthMetricsUnit } from '@kit.ArkUI';
import { Bill, ReceiptTemplate, ReceiptTextElement, CustomCharge, defaultReceiptElements } from '../model/Models';
import { receiptCharges, resolveReceipt } from '../model/ReceiptContent';

class Cell { left: number = 0; top: number = 0; width: number = 0; height: number = 0; }
function cell(id: string, offset: number): Cell | undefined {
  let top = 0; let height = 300;
  if (id.startsWith('head')) { top = 285; height = 215; }
  else if (id.startsWith('water')) { top = 500; }
  else if (id.startsWith('electric')) { top = 800; }
  else if (id.startsWith('rent')) { top = 1100; }
  else if (id.startsWith('total')) { top = 1400+offset; height = 400; }
  else { return undefined; }
  let left = 95; let right = 620;
  if (id === 'totalUpper') { left = 620; right = 2440; }
  else if (id === 'total') { left = 2440; right = 3413; }
  else if (id === 'totalLabel' || id.endsWith('Label') || id === 'headItem') {}
  else if (id.endsWith('Current')) { left = 620; right = 1100; }
  else if (id.endsWith('Previous')) { left = 1100; right = 1580; }
  else if (id.endsWith('Usage')) { left = 1580; right = 2060; }
  else if (id.endsWith('Rate')) { left = 2060; right = 2540; }
  else if (id.endsWith('Amount')) { left = 2540; right = 3413; }
  else { return undefined; }
  return {left:left,top:top,width:right-left,height:height};
}
function text(c: OffscreenCanvasRenderingContext2D, value: string, x: number, y: number, size: number, color: string, max: number, center: boolean): void {
  c.fillStyle = color; c.textAlign = center ? 'center' : 'left'; c.textBaseline = 'middle';
  c.font = 'bold ' + size + 'px serif';
  while (c.measureText(value).width > max && size > 24) { size -= 2; c.font = 'bold ' + size + 'px serif'; }
  c.fillText(value,x,y,max);
}
export function renderReceipt(b: Bill, buildingName: string, template: ReceiptTemplate): OffscreenCanvasRenderingContext2D {
  const charges = receiptCharges(b); const offset = charges.length*300;
  const c = new OffscreenCanvasRenderingContext2D(px2vp(3508),px2vp(1970+offset),new RenderingContextSettings(true),LengthMetricsUnit.PX);
  c.fillStyle = '#FFFCF4'; c.fillRect(0,0,3508,1970+offset); c.translate(0,70);
  c.strokeStyle = '#252525'; c.lineWidth = 5; c.strokeRect(95,285,3318,1515+offset);
  [620,1100,1580,2060,2540].forEach((x: number) => {
    c.beginPath(); c.moveTo(x,285); c.lineTo(x,x === 620 || x === 2540 ? 1400+offset : 1100); c.stroke();
  });
  const rows = [500,800,1100,1400];
  charges.forEach((charge: CustomCharge,i: number) => { rows.push(1400+(i+1)*300); }); rows.push(1800+offset);
  rows.forEach((y: number) => { c.beginPath(); c.moveTo(95,y); c.lineTo(3413,y); c.stroke(); });
  charges.forEach((charge: CustomCharge,i: number) => {
    text(c,charge.name,357.5,1550+i*300,66,'#252525',485,true);
    text(c,charge.amount,2976.5,1550+i*300,136,'#124997',833,true);
  });
  const missing = defaultReceiptElements().filter((e: ReceiptTextElement) => ['headRate','waterRate','electricRate'].includes(e.id) && !template.elements.some((own: ReceiptTextElement) => own.id === e.id));
  template.elements.concat(missing).forEach((e: ReceiptTextElement) => {
    if (!b.managementRate?.trim() && ['headRate','waterRate','electricRate'].includes(e.id)) { return; }
    if (e.id === 'rentUsage' || e.id === 'roomSuffix') { return; }
    const value = resolveReceipt(e.content,b,buildingName); const bounds = cell(e.id,offset);
    const color = e.color === 'blue' ? '#124997' : e.color === 'red' ? '#9A1824' : '#252525';
    if (bounds) {
      const size = e.id.startsWith('head') || e.id.endsWith('Label') ? 66 : e.id === 'totalUpper' ? e.fontSize : 136;
      text(c,value,bounds.left+bounds.width/2,bounds.top+bounds.height/2,size,color,bounds.width-40,true);
    } else {
      const max = e.id === 'title' ? 2500 : e.id === 'receiptNo' ? 620 : e.id === 'date' ? 850 : 1500;
      text(c,value,Math.max(95,Math.min(e.x,3413-(e.centered?0:max))),e.y-e.fontSize/3,e.fontSize,color,max,e.centered);
    }
  });
  return c;
}
