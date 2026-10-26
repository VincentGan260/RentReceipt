import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { LengthMetricsUnit } from '@kit.ArkUI';
import { util } from '@kit.ArkTS';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { AppData, Bill, Room, compareRoomNumbers } from '../model/Models';
import { Decimal } from '../model/Decimal';
import { shiftMonth, validateMonth } from '../model/BillCalculator';
import { usage } from '../model/ReceiptContent';
import { rasterPdf, PdfImage, PdfText, pdfCharacters } from './RasterPdf';
import { safeName } from './ReceiptService';

function drawText(c: OffscreenCanvasRenderingContext2D,texts: PdfText[],s: string,x: number,y: number,width: number,size: number = 9): void {
  c.font = size+'px serif'; c.fillStyle = '#232323'; c.textAlign = 'center'; c.textBaseline = 'middle'; c.fillText(s,x+width/2,y,width-4);
  const measured = c.measureText(s).width; const rendered = Math.min(measured,width-4);
  texts.push({text:s,x:x+(width-rendered)/2,baseline:595-y-size*0.35,size:size,width:rendered,
    characterWidths:pdfCharacters(s).map((ch: string) => c.measureText(ch).width/size*1000)});
}
function line(c: OffscreenCanvasRenderingContext2D,x: number,y: number,x2: number,y2: number): void { c.beginPath(); c.moveTo(x,y); c.lineTo(x2,y2); c.stroke(); }
function sum(bills: Bill[],kind: number): string {
  return bills.reduce((n: Decimal,b: Bill) => n.add(Decimal.parse(kind === 0 ? b.waterAmount : kind === 1 ? b.electricityAmount : b.total)),Decimal.zero()).toString();
}
export async function archivePdf(context: common.UIAbilityContext,data: AppData,buildingId: string,start: string,end: string): Promise<boolean> {
  validateMonth(start); validateMonth(end); if (start > end) { throw new Error('结束月份不能早于开始月份'); }
  const months: string[] = []; let month = start;
  while (month <= end) { months.push(month); if (months.length > 120) { throw new Error('每次最多导出 120 个月，请分段导出'); } month = shiftMonth(month,1); }
  const building = data.buildings.find((b) => b.id === buildingId); if (!building) { throw new Error('楼栋不存在'); }
  const rooms = data.rooms.filter((r: Room) => r.buildingId === buildingId).sort((a: Room,b: Room) => compareRoomNumbers(a.number,b.number));
  if (!rooms.length) { throw new Error('当前楼栋没有房间'); }
  const bills = data.bills.filter((b: Bill) => b.buildingId === buildingId); const pages: PdfImage[] = [];
  const count = Math.ceil(rooms.length/15)*Math.ceil(months.length/3);
  if (count > 100) { throw new Error('页面超过 100 页，请缩短月份范围'); }
  for (let mi = 0; mi < months.length; mi += 3) {
    const group = months.slice(mi,mi+3); const mw = 546/group.length;
    for (let ri = 0; ri < rooms.length; ri += 15) {
      const rs = rooms.slice(ri,ri+15);
      const texts: PdfText[] = [];
      const c = new OffscreenCanvasRenderingContext2D(px2vp(1684),px2vp(1190),new RenderingContextSettings(true),LengthMetricsUnit.PX); c.scale(2,2);
      c.fillStyle = '#FFFFFF'; c.fillRect(0,0,842,595); c.lineWidth = 0.8; c.strokeStyle = '#2D2D2D';
      drawText(c,texts,building.name+' 房屋水电留档  '+start+' 至 '+end,30,30,782,17);
      const xs = [30,96,142,194,266]; group.forEach((m: string,i: number) => xs.push(266+mw*(i+1)));
      const bottom = 96+(rs.length+1)*28;
      xs.forEach((x: number) => line(c,x,52,x,bottom)); [52,96].forEach((y: number) => line(c,30,y,812,y));
      for (let i = 0; i <= rs.length; i++) { line(c,30,96+(i+1)*28,812,96+(i+1)*28); }
      ['房号','出租','租金','押金'].forEach((s: string,i: number) => drawText(c,texts,s,xs[i],78,xs[i+1]-xs[i]));
      group.forEach((m: string,i: number) => {
        const left = xs[4+i]; drawText(c,texts,m,left,65,mw); line(c,left,72,left+mw,72);
        for (let j = 1; j < 3; j++) { line(c,left+mw*j/3,72,left+mw*j/3,bottom); }
        ['水(m³)','电(度)','总额(元)'].forEach((s: string,j: number) => drawText(c,texts,s,left+mw*j/3,85,mw/3));
      });
      rs.forEach((r: Room,i: number) => {
        const y = 110+i*28;
        [r.number,r.occupied?'已租':'空置',r.rent,r.depositAmount+'/'+(r.depositStatus==='COLLECTED'?'已收':r.depositStatus==='REFUNDED'?'已退':'未收')].forEach((s: string,j: number) => drawText(c,texts,s,xs[j],y,xs[j+1]-xs[j]));
        group.forEach((m: string,j: number) => {
          const b = bills.find((b: Bill) => b.roomId === r.id && b.month === m);
          const values = b ? [usage(b,true),usage(b,false),b.total] : ['-','-','-'];
          values.forEach((s: string,k: number) => drawText(c,texts,s,xs[j+4]+mw*k/3,y,mw/3));
        });
      });
      const y = 110+rs.length*28; drawText(c,texts,'月汇总',30,y,66); drawText(c,texts,'费用',96,y,170);
      group.forEach((m: string,j: number) => {
        const selected = bills.filter((b: Bill) => b.month === m);
        [0,1,2].forEach((k: number) => drawText(c,texts,sum(selected,k),xs[j+4]+mw*k/3,y,mw/3));
      });
      drawText(c,texts,'按当前房间资料列示；月汇总包含该楼栋当月全部历史账单。',30,560,650,9);
      drawText(c,texts,String(pages.length+1)+' / '+count,730,560,82,9);
      const pixels = c.getPixelMap(0,0,1684,1190);
      const packer = image.createImagePacker();
      try {
        const info = await pixels.getImageInfo();
        const jpeg = await packer.packing(pixels,{format:'image/jpeg',quality:95});
        pages.push({width:info.size.width,height:info.size.height,jpeg:new Uint8Array(jpeg),texts:texts});
      } finally { await packer.release(); await pixels.release(); }
      await new Promise<void>((resolve) => setTimeout(resolve,0));
    }
  }
  const bytes = rasterPdf(pages); const options = new picker.DocumentSaveOptions();
  options.newFileNames = [safeName(building.name+'_'+start+'_至_'+end+'_房屋留档')+'.pdf']; options.fileSuffixChoices = ['PDF 文件|.pdf'];
  const uris = await new picker.DocumentViewPicker(context).save(options); if (!uris.length) { return false; }
  const f = await fs.open(uris[0],fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
  try { if (await fs.write(f.fd,bytes.buffer) !== bytes.length) { throw new Error('PDF 写入不完整'); } await fs.fsync(f.fd); }
  finally { await fs.close(f); } return true;
}
