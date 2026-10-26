const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs'), path = require('node:path'), os = require('node:os');
const {execFileSync} = require('node:child_process');
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript');
require.extensions['.ets'] = (m,f) => m._compile(ts.transpileModule(fs.readFileSync(f,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText,f);
const root = path.resolve(__dirname,'../..');
const base = root + '/harmonyos/entry/src/main/ets';
const M=require(base+'/model/Models.ets'), C=require(base+'/model/BillCalculator.ets');
const B=require(base+'/data/BackupTables.ets'), Z=require(base+'/data/BackupZip.ets');
const {RentStore}=require(base+'/data/RentStore.ets');
function fixture() {
 const data=M.initialData(); data.buildings[0].name='楼栋,"甲"\n二楼'; data.buildings[0].settings.defaultElectricityMeterMax=undefined;
 data.buildings[0].settings.defaultManagementRate='0.2'; data.buildings[0].receiptTemplate=new M.ReceiptTemplate();
 const room=Object.assign(new M.Room(),{id:'r',number:'铺101',rent:'650.00',occupied:true,depositStatus:'REFUNDED',depositAmount:'1000',depositCollectedDate:'2026-01-01',depositRefundedDate:'2026-10-01',customManagementRate:'0',recurringCharges:[{name:'网络,"专线"\n费',amount:'29.5'}]});
 data.rooms=[room];
 const draft=Object.assign(new M.BillDraft(),{month:'2026-10',previousWater:'100',currentWater:'102',previousElectricity:'1000',currentElectricity:'1100',customCharges:[{name:'补收房租·2026-09',amount:'650'},{name:'清洁费',amount:'10'}]});
 const bill=C.createBill(room,data.buildings[0].settings,draft,'b'); bill.paid=true; bill.paidDate='2026-10-12'; data.bills=[bill];return data;
}
function canonical(o){return JSON.parse(JSON.stringify(o));}
test('v10 preserves all data including templates, quotes, multiline Chinese and explicitly blank meter caps',()=>{
 const data=fixture();assert.deepEqual(canonical(B.importTables(B.exportTables(data))),canonical(data));
 assert.deepEqual(B.parseCsv('\ufeff"a","b"\r\n"一\n二","x""y"\r\n'),[['a','b'],['一\n二','x"y']]);
 for(const bad of ['a,a\n1,2','a\n"unfinished','a\n"ok"oops'])assert.throws(()=>B.parseCsv(bad));
});
test('versions 1–9 migrate their available fields and reject unknown versions and broken references',()=>{
 for(let v=2;v<=9;v++) {
  const files=B.exportTables(fixture()); files.find(f=>f.name==='manifest.csv').text=B.csv([['format','version'],['rent-receipt',String(v)]]);
  const data=B.importTables(files);assert.equal(data.rooms[0].occupied,v>=4);assert.equal(data.bills[0].customCharges.length,v>=8?2:0);
  assert.equal(data.buildings[0].settings.defaultElectricityMeterMax,v>=6?undefined:'10000');
 }
 const old=[{name:'manifest.csv',text:'format,version\nrent-receipt,1\n'},{name:'settings.csv',text:'key,value\ndefault_water_rate,6\ndefault_electricity_rate,1.5\n'},...B.exportTables(fixture()).filter(f=>['rooms.csv','bills.csv'].includes(f.name))];
 const data=B.importTables(old);assert.equal(data.buildings[0].settings.defaultWaterRate,'6');assert.equal(data.bills[0].waterUsage,'');
 const files=B.exportTables(fixture());files.find(f=>f.name==='rooms.csv').text=files.find(f=>f.name==='rooms.csv').text.replace('default-building','missing');assert.throws(()=>B.importTables(files));
});
test('restore commits atomically, clears old drafts only on success, and survives reopen',async()=>{
 const storage={text:undefined,fail:false,async read(){return this.text},async write(s){if(this.fail)throw Error('disk full');this.text=s}};
 const store=await RentStore.open(storage);const f=fixture();await store.saveRoom(f.rooms[0]);
 const draft=Object.assign(new M.BillDraft(),{month:'2026-10'});await store.saveDraft(M.DEFAULT_BUILDING_ID,'r',draft);
 const before=store.snapshot();storage.fail=true;await assert.rejects(store.restore(f),/disk full/);assert.deepEqual(store.snapshot(),before);
 storage.fail=false;await store.restore(f);assert.equal(store.snapshot().drafts.length,0);assert.deepEqual(canonical((await RentStore.open(storage)).snapshot().data),canonical(f));
});
test('standard ZIP interoperability, CRC and compressed Android-style streams',()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'rentreceipt-zip-'));
 try {
  const files=B.exportTables(fixture());const bytes=Z.writeZip(files.map(f=>({name:f.name,bytes:new TextEncoder().encode(f.text)})));
  fs.writeFileSync(dir+'/backup.zip',bytes);assert.equal(Z.inspectZip(bytes).length,7);assert.equal(Z.crc32(new TextEncoder().encode('123456789')),0xcbf43926);
  execFileSync('/usr/bin/python3',['-c',`import zipfile,sys\np=sys.argv[1]\nwith zipfile.ZipFile(p+'/backup.zip') as z:\n assert z.testzip() is None\n with zipfile.ZipFile(p+'/deflated.zip','w',zipfile.ZIP_DEFLATED) as d:\n  for n in z.namelist(): d.writestr(n,z.read(n))\n`,dir]);
  assert.equal(Z.inspectZip(new Uint8Array(fs.readFileSync(dir+'/deflated.zip'))).length,7);
  for(const localOnly of [true,false]) {
   const b=bytes.slice();const view=new DataView(b.buffer);if(localOnly){b[30]=46}else{const central=view.getUint32(b.length-6,true);b[central+46]=46}assert.throws(()=>Z.inspectZip(b));
  }
  assert.throws(()=>Z.inspectZip(bytes.slice(0,-1))); const huge=bytes.slice();new DataView(huge.buffer).setUint32(new DataView(huge.buffer).getUint32(huge.length-6,true)+24,Z.BACKUP_LIMIT+1,true);assert.throws(()=>Z.inspectZip(huge));
 }finally{fs.rmSync(dir,{recursive:true,force:true})}
});
test('actual iOS importer reads Harmony ZIP and its exporter roundtrips every CSV field',()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'rentreceipt-backup-ios-'));
 try {
  const f=fixture(), files=B.exportTables(f);fs.writeFileSync(dir+'/input.zip',Z.writeZip(files.map(f=>({name:f.name,bytes:new TextEncoder().encode(f.text)}))));
  const overview=fs.readFileSync(root+'/ios/RentReceipt/RentReceipt/OverviewView.swift','utf8');const start=overview.indexOf('struct MonthValue: Hashable {');let depth=0,end=start;
  for(;end<overview.length;end++){if(overview[end]==='{')depth++;if(overview[end]==='}'&&--depth===0){end++;break}}
  fs.writeFileSync(dir+'/MonthValue.swift','import Foundation\n'+overview.slice(start,end));
  fs.writeFileSync(dir+'/main.swift',`import Foundation\nlet data = try BackupArchive.importArchive(from: URL(fileURLWithPath: CommandLine.arguments[1]))\nlet output = try BackupArchive.export(data)\ntry FileManager.default.copyItem(at: output, to: URL(fileURLWithPath: CommandLine.arguments[2]))\n`);
  const swift=root+'/ios/RentReceipt/RentReceipt/';execFileSync('/usr/bin/xcrun',['swiftc','-module-cache-path',dir+'/cache',swift+'Models.swift',swift+'BillCalculator.swift',swift+'BackupArchive.swift',dir+'/MonthValue.swift',dir+'/main.swift','-o',dir+'/check'],{timeout:60000});
  execFileSync(dir+'/check',[dir+'/input.zip',dir+'/output.zip']);
  const output=JSON.parse(execFileSync('/usr/bin/python3',['-c',`import sys,zipfile,json\nwith zipfile.ZipFile(sys.argv[1]) as z: print(json.dumps([{'name':n,'text':z.read(n).decode('utf-8')} for n in z.namelist()]))`,dir+'/output.zip'],{encoding:'utf8'}));
  const expected=canonical(f);
  assert.deepEqual(canonical(B.importTables(output)),expected);
 }finally{fs.rmSync(dir,{recursive:true,force:true})}
});

test('confirmed bidirectional batch payment is atomic and isolated by building and month',async()=>{
 const storage={text:undefined,async read(){return this.text},async write(s){this.text=s}};
 const store=await RentStore.open(storage),data=fixture();
 data.buildings.push(Object.assign(new M.Building(),{id:'other',name:'另一栋'}));
 data.bills.push(Object.assign(new M.Bill(),data.bills[0],{id:'other-bill',roomId:'other-room',buildingId:'other'}));
 await store.restore(data);
 await store.markMonthPaid(M.DEFAULT_BUILDING_ID,'2026-10','2026-10-17',false);
 let bills=store.snapshot().data.bills;assert.equal(bills[0].paid,false);assert.equal(bills[0].paidDate,undefined);assert.equal(bills[1].paidDate,'2026-10-12');
 await store.markMonthPaid(M.DEFAULT_BUILDING_ID,'2026-10','2026-10-17',true);
 await store.markMonthPaid(M.DEFAULT_BUILDING_ID,'2026-10','2026-10-18',true);
 bills=store.snapshot().data.bills;assert.equal(bills[0].paidDate,'2026-10-17');assert.equal(bills[1].paidDate,'2026-10-12');
});
