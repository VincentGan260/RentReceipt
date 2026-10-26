export class PdfText {
  text: string = '';
  x: number = 0;
  baseline: number = 0;
  size: number = 9;
  width: number = 0;
  characterWidths?: number[];
}
export function pdfCharacters(value: string): string[] {
  const result: string[] = [];
  for (let i = 0; i < value.length; i++) {
    let next = value.charAt(i); const code = value.charCodeAt(i);
    if (code >= 0xD800 && code <= 0xDBFF && i+1 < value.length) {
      const low = value.charCodeAt(i+1);
      if (low >= 0xDC00 && low <= 0xDFFF) { next += value.charAt(++i); }
    }
    result.push(next);
  }
  return result;
}
function hex16(value: string): string {
  let result = '';
  for (let i = 0; i < value.length; i++) { result += value.charCodeAt(i).toString(16).padStart(4,'0').toUpperCase(); }
  return result;
}
class TextFont {
  ids: Map<string,number> = new Map();
  widths: number[] = [];
  mapping: string = '';
  constructor(pages: PdfImage[]) {
    pages.forEach((p: PdfImage) => (p.texts ?? []).forEach((t: PdfText) => {
      pdfCharacters(t.text).forEach((ch: string,i: number) => {
        if (this.ids.has(ch)) { return; }
        if (this.ids.size >= 65535) { throw new Error('PDF 字符种类过多，请分段导出'); }
        this.ids.set(ch,this.ids.size+1);
        const measured = t.characterWidths?.[i];
        this.widths.push(measured !== undefined && Number.isFinite(measured) && measured >= 0 ? measured : 1000);
      });
    }));
    const lines: string[] = [];
    this.ids.forEach((id: number,ch: string) => lines.push('<'+id.toString(16).padStart(4,'0')+'> <'+hex16(ch)+'>'));
    this.mapping = '/CIDInit /ProcSet findresource begin\n12 dict begin\nbegincmap\n/CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def\n/CMapName /RentReceiptUnicode def\n/CMapType 2 def\n1 begincodespacerange\n<0000> <FFFF>\nendcodespacerange\n';
    for (let i = 0; i < lines.length; i += 100) {
      const block = lines.slice(i,i+100);
      this.mapping += block.length+' beginbfchar\n'+block.join('\n')+'\nendbfchar\n';
    }
    this.mapping += 'endcmap\nCMapName currentdict /CMap defineresource pop\nend\nend\n';
  }
  content(texts: PdfText[]): string {
    return texts.filter((t: PdfText) => !!t.text).map((t: PdfText) => {
      const chars = pdfCharacters(t.text); let hex = ''; let units = 0;
      chars.forEach((ch: string) => { const id = this.ids.get(ch)!; hex += id.toString(16).padStart(4,'0'); units += this.widths[id-1]; });
      const natural = units*t.size/1000;
      const scale = natural > 0 ? t.width/natural*100 : 100;
      return 'BT /F1 '+t.size.toFixed(4)+' Tf 3 Tr '+scale.toFixed(6)+' Tz 1 0 0 1 '+t.x.toFixed(4)+' '+t.baseline.toFixed(4)+' Tm <'+hex+'> Tj ET\n';
    }).join('');
  }
}
export class PdfImage { texts?: PdfText[]; jpeg: Uint8Array = new Uint8Array(); width: number = 0; height: number = 0; }
function ascii(s: string): Uint8Array { const b = new Uint8Array(s.length); for (let i = 0; i < s.length; i++) { b[i] = s.charCodeAt(i); } return b; }
export function rasterPdf(pages: PdfImage[]): Uint8Array {
  if (!pages.length) { throw new Error('PDF 没有页面'); }
  const parts: Uint8Array[] = []; const offsets: number[] = [0]; let length = 0;
  const append = (b: Uint8Array): void => { parts.push(b); length += b.length; };
  const text = (s: string): void => append(ascii(s));
  const object = (id: number, s: string): void => { offsets[id] = length; text(id+' 0 obj\n'+s+'\nendobj\n'); };
  const font = new TextFont(pages); const fontId = 3 + pages.length*3;
  text('%PDF-1.4\n'); object(1,'<< /Type /Catalog /Pages 2 0 R >>');
  object(2,'<< /Type /Pages /Count '+pages.length+' /Kids ['+pages.map((p: PdfImage,i: number) => (3+i*3)+' 0 R').join(' ')+'] >>');
  pages.forEach((p: PdfImage,i: number) => {
    const id = 3+i*3;
    object(id,'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 842 595] /Resources << /XObject << /Im0 '+(id+2)+' 0 R >>' + (font.ids.size ? ' /Font << /F1 '+fontId+' 0 R >>' : '') + ' >> /Contents '+(id+1)+' 0 R >>');
    const content = 'q 842 0 0 595 0 0 cm /Im0 Do Q\n' + font.content(p.texts ?? []);
    object(id+1,'<< /Length '+content.length+' >>\nstream\n'+content+'endstream');
    offsets[id+2] = length;
    text((id+2)+' 0 obj\n<< /Type /XObject /Subtype /Image /Width '+p.width+' /Height '+p.height+' /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length '+p.jpeg.length+' >>\nstream\n');
    append(p.jpeg); text('\nendstream\nendobj\n');
  });
  if (font.ids.size) {
    object(fontId,'<< /Type /Font /Subtype /Type0 /BaseFont /RentReceiptUnicode /Encoding /Identity-H /DescendantFonts ['+(fontId+1)+' 0 R] /ToUnicode '+(fontId+3)+' 0 R >>');
    object(fontId+1,'<< /Type /Font /Subtype /CIDFontType2 /BaseFont /RentReceiptUnicode /CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> /FontDescriptor '+(fontId+2)+' 0 R /CIDToGIDMap /Identity /DW 1000 /W [1 ['+font.widths.map((n: number) => n.toFixed(4)).join(' ')+']] >>');
    object(fontId+2,'<< /Type /FontDescriptor /FontName /RentReceiptUnicode /Flags 4 /FontBBox [0 -200 2000 1000] /ItalicAngle 0 /Ascent 800 /Descent -200 /CapHeight 700 /StemV 80 >>');
    object(fontId+3,'<< /Length '+font.mapping.length+' >>\nstream\n'+font.mapping+'endstream');
  }
  const xref = length; text('xref\n0 '+offsets.length+'\n0000000000 65535 f \n');
  for (let i = 1; i < offsets.length; i++) { text(String(offsets[i]).padStart(10,'0')+' 00000 n \n'); }
  text('trailer\n<< /Size '+offsets.length+' /Root 1 0 R >>\nstartxref\n'+xref+'\n%%EOF\n');
  const output = new Uint8Array(length); let p = 0; parts.forEach((b: Uint8Array) => { output.set(b,p); p += b.length; }); return output;
}
