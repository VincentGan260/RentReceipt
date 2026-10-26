const {test}=require('node:test'), assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {execFileSync}=require('node:child_process');
const ts=require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript');
require.extensions['.ets']=(m,f)=>m._compile(ts.transpileModule(fs.readFileSync(f,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,f);
const base=path.resolve(__dirname,'../entry/src/main/ets');
const M=require(base+'/model/Models.ets'),R=require(base+'/model/ReceiptContent.ets'),P=require(base+'/export/RasterPdf.ets');
test('receipt placeholders preserve saved rollover usage, charges and exact large RMB uppercase',()=>{
 const b=Object.assign(new M.Bill(),{roomNumber:'101',month:'2026-10',previousWater:'99',currentWater:'1',waterUsage:'2',previousElectricity:'9999',currentElectricity:'20',electricityUsage:'21',total:'795',managementRate:'0',managementAmount:'0',customCharges:[{name:'网络费',amount:'30'}]});
 assert.equal(R.resolveReceipt('{room} {date} 水{waterUsage} 电{electricityUsage} {totalUpper}',b,'甲楼'),'101号（甲楼） 2026 年 10 月 1 日 水2 电21 柒佰玖拾伍元整');
 assert.deepEqual(R.receiptCharges(b),[{name:'公共服务费',amount:'0'},{name:'网络费',amount:'30'}]);
 for(const [n,s] of [['0','零元整'],['10','壹拾元整'],['10001','壹万零壹元整'],['100000001','壹亿零壹元整'],['100100001','壹亿零壹拾万零壹元整'],['9999999999999999','玖仟玖佰玖拾玖兆玖仟玖佰玖拾玖亿玖仟玖佰玖拾玖万玖仟玖佰玖拾玖元整']])assert.equal(R.rmbUpper(n),s,n);
});
test('PDF page tree and xref offsets are readable by an independent strict PDF parser',()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'rentreceipt-pdf-'));
 try {
  const image=Uint8Array.from([255,216,255,217]);const bytes=P.rasterPdf([{jpeg:image,width:1684,height:1190},{jpeg:image,width:1684,height:1190}]);
  fs.writeFileSync(dir+'/test.pdf',bytes);
  execFileSync('/Users/vincent/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3',['-c',`from pypdf import PdfReader\nimport sys\nr=PdfReader(sys.argv[1],strict=True)\nassert len(r.pages)==2\nfor p in r.pages:\n assert list(p.mediabox)==[0,0,842,595]\n assert p.get_contents().get_data()==b'q 842 0 0 595 0 0 cm /Im0 Do Q\\n'\n assert p['/Resources']['/XObject']['/Im0']['/Width']==1684\n`,dir+'/test.pdf']);
 }finally{fs.rmSync(dir,{recursive:true,force:true})}
});

test('PDF Chinese, digits, punctuation and supplementary Unicode have searchable text mappings',()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'rentreceipt-text-pdf-'));
 try {
  const text='甲楼𠀀 101 房租（水） ¥ 795.00 <复制> (安全)';
  const chars=P.pdfCharacters(text);assert.ok(chars.includes('𠀀'));
  const page={jpeg:Uint8Array.from([255,216,255,217]),width:1684,height:1190,texts:[{text,x:30,baseline:550,size:12,width:380,characterWidths:chars.map(ch=>ch.charCodeAt(0)<128?500:1000)}]};
  fs.writeFileSync(dir+'/text.pdf',P.rasterPdf([page]));
  execFileSync('/Users/vincent/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3',['-c',`from pypdf import PdfReader\nimport sys\nr=PdfReader(sys.argv[1],strict=True)\np=r.pages[0]\nassert p.extract_text()==sys.argv[2],repr(p.extract_text())\nassert b'3 Tr' in p.get_contents().get_data()\nassert '/ToUnicode' in p['/Resources']['/Font']['/F1']\n`,dir+'/text.pdf',text]);
 }finally{fs.rmSync(dir,{recursive:true,force:true})}
});
const {runReceiptBatch}=require(base+'/export/ReceiptBatch.ets');
test('stopping receipt generation never invokes gallery save and cleans only generated temporary files',async()=>{
 const removed=[],rendered=[];let cancel=false,saves=0;
 const result=await runReceiptBatch([{id:'one'},{id:'two'}],async b=>{rendered.push(b.id);return '/cache/'+b.id},async()=>{saves++;return 2},async p=>removed.push(p),()=>cancel,()=>{cancel=true});
 assert.equal(result.cancelled,true);assert.equal(result.total,2);assert.equal(result.saved,0);assert.equal(saves,0);
 assert.deepEqual(rendered,['one']);assert.deepEqual(removed,['/cache/one']);
});
test('batch render/save failures preserve the original error while cleaning completed temporary images',async()=>{
 for(const stage of ['render','save']){
  const removed=[];
  await assert.rejects(runReceiptBatch([{id:'one'},{id:'two'}],async b=>{if(stage==='render'&&b.id==='two')throw Error('render failed');return '/cache/'+b.id},async()=>{throw Error('save failed')},async p=>{removed.push(p);throw Error('cleanup failed')},()=>false,()=>{}),new RegExp(stage+' failed'));
  assert.deepEqual(removed,stage==='render'?['/cache/one']:['/cache/one','/cache/two']);
 }
});
test('successful batch reports actual saved count and releases all generated temporary files',async()=>{
 const removed=[],progress=[];
 const result=await runReceiptBatch([{id:'one'},{id:'two'}],async b=>'/cache/'+b.id,async paths=>{assert.equal(paths.length,2);return 1},async p=>removed.push(p),()=>false,(n,total)=>progress.push([n,total]));
 assert.equal(result.saved,1);assert.equal(result.cancelled,false);assert.deepEqual(progress,[[1,2],[2,2]]);assert.equal(removed.length,2);
});
