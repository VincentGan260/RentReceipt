import { HdsNavigation, HdsNavigationAttribute, HdsNavDestinationAttribute, HdsTabsAttribute, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import * as hds from '@hms.hds.hdsBaseComponent';
import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { supportsImmersiveNavigation, gradientTitleBar } from '../ui/ImmersiveNavigation';
import { KeyboardAvoidMode, FrameCallback } from '@kit.ArkUI';
import { SymbolGlyphModifier } from '@ohos.arkui.modifier';
import { runReceiptBatch } from '../export/ReceiptBatch';
import { fileIo as fs } from '@kit.CoreFileKit';
import { SettingsPage } from '../ui/SettingsPage';
import { AboutPage } from '../ui/AboutPage';
import { ArchivePage } from '../ui/ArchivePage';
import { TemplatePage } from '../ui/TemplatePage';
import { common } from '@kit.AbilityKit';
import { receiptPng, saveReceiptImages } from '../export/ReceiptService';
import { ReceiptPage } from '../ui/ReceiptPage';
import { BackupPage } from '../ui/BackupPage';
import { util } from '@kit.ArkTS';
import { AppData, Building, Room, Bill, compareRoomNumbers } from '../model/Models';
import { monthTitle, currentMonth, monthSummary, MonthSummary, today, buildingMissingMonths } from '../model/UiLogic';
import { shiftMonth } from '../model/BillCalculator';
import { StoreSession } from '../data/StoreSession';
import { BuildingEditor, RoomEditor } from '../ui/Editors';
import { EntryCard } from '../ui/EntryCard';
import { RoomHistory, BillDetail, PageRoute } from '../ui/History';

// Namespace access tolerates exports absent on HarmonyOS 5.1.
const HdsTabs = hds.HdsTabs;

class SearchFocusFrame extends FrameCallback {
  private focus: () => void;
  constructor(focus: () => void) { super(); this.focus = focus; }
  onIdle(): void { this.focus(); }
}

class OverviewRow {
  id: string = '';
  number: string = '';
  bill?: Bill;
}

@Entry
@Component
struct Index {
  @StorageLink('statusBarContentColor') statusBarContentColor: string = '#000000';
  @StorageLink('pageScale') uiScale: number = 1;
  private immersiveNavigation: boolean = supportsImmersiveNavigation();
  private overviewScroller: Scroller = new Scroller();
  private entryScroller: Scroller = new Scroller();
  private roomsScroller: Scroller = new Scroller();
  private searchController: SearchController = new SearchController();
  private homeTabsController?: hds.HdsTabsController = this.immersiveNavigation ? new hds.HdsTabsController() : undefined;
  private pendingSearchFocus: boolean = false;
  private paths: NavPathStack = new NavPathStack();
  @StorageLink('animations') @Watch('updateAnimations') animations: boolean = true;
  private updateAnimations(): void { this.paths.disableAnimation(!this.animations); }
  @State data: AppData = new AppData();
  @State buildingId: string = '';
  @State tab: number = 0;
  @State overviewMonth: string = currentMonth();
  @State readingMonth: string = currentMonth();
  @State query: string = '';
  @State searching: boolean = false;
  @State miniBarExpanded: boolean = false;
  @State searchContentVisible: boolean = false;
  @State contentWidth: number = 360;
  @State message: string = '';
  @State busy: boolean = false;
  @State exporting: boolean = false;
  @State cancelExport: boolean = false;
  @State exportStatus: string = '';
  @State detailOpen: boolean = false;
  @State missingRentMonths: string[] = [];
  @State entryRevision: number = 0;

  aboutToAppear(): void {
    this.getUIContext().setKeyboardAvoidMode(this.immersiveNavigation ? KeyboardAvoidMode.RESIZE : KeyboardAvoidMode.OFFSET);
    this.paths.setInterception({ willShow: (from, to, operation, animated) => {
      this.detailOpen = typeof to !== 'string';
    } });
    this.reload(); this.updateAnimations();
  }

  onBackPress(): boolean {
    if ((this.searching || this.pendingSearchFocus) && !this.detailOpen) {
      if (this.immersiveNavigation) { this.endNativeSearch(); }
      else { this.searchController.stopEditing(); this.query = ''; this.searching = false; }
      return true;
    }
    return false;
  }

  private reload(): void {
    if (!StoreSession.store) { return; }
    this.data = StoreSession.store.snapshot().data;
    if (!this.data.buildings.some((building: Building) => building.id === this.buildingId)) {
      this.buildingId = this.data.buildings[0]?.id ?? '';
    }
    StoreSession.entries?.prune(this.data);
  }

  private building(): Building | undefined { return this.data.buildings.find((building: Building) => building.id === this.buildingId); }
  private billMonth(): string { return shiftMonth(this.readingMonth, 1); }
  private rooms(): Room[] {
    return this.data.rooms.filter((room: Room) => room.buildingId === this.buildingId &&
      room.number.toLowerCase().includes(this.query.trim().toLowerCase()))
      .sort((a: Room, b: Room) => compareRoomNumbers(a.number, b.number));
  }
  private summary(): MonthSummary { return monthSummary(this.data, this.buildingId, this.overviewMonth); }
  private pageMargin(): number { return this.contentWidth >= 840 ? 32 : this.contentWidth >= 600 ? 24 : 16; }
  private pageWidth(): number { return Math.min(this.contentWidth, 960); }
  private roomColumns(): number {
    const available = this.pageWidth() - this.pageMargin() * 2 - 16;
    return this.contentWidth >= 840 && available >= 680 * this.uiScale ? 2 : 1;
  }
  private compactTabWidth(): number { return Math.max(168, Math.min(248, this.contentWidth - 96)); }
  private compactSearchWidth(): number {
    // Fill the remaining row: page margins, 56vp collapsed tab and an 8vp gap.
    return Math.max(168, this.contentWidth - this.tabSideMargin() * 2 - 56 - 8);
  }
  private tabSideMargin(): number {
    // Native collapsed search is 56vp. Center the whole group with an 8vp gap.
    if (this.contentWidth < 440) {
      return Math.max(16, (this.contentWidth - this.compactTabWidth() - 56 - 8) / 2);
    }
    return this.pageMargin();
  }

  private beginNativeSearch(): void {
    this.pendingSearchFocus = true;
    this.homeTabsController?.applyMiniBarStyle(hds.HdsBarStyle.EXPAND);
  }

  private focusNativeSearch(attempt: number = 0): void {
    // Focus on the next frame, alongside the bar animation rather than after it.
    this.getUIContext().postFrameCallback(new SearchFocusFrame(() => {
      if (!this.pendingSearchFocus || !this.searchContentVisible) { return; }
      try {
        this.getUIContext().getFocusController().requestFocus('nativeRoomSearch');
        this.pendingSearchFocus = false;
        this.searching = true;
      } catch (_) {
        // The native bar may still be attaching its input; retry after layout.
        if (attempt < 2) { this.focusNativeSearch(attempt + 1); }
      }
    }));
  }

  private endNativeSearch(): void {
    this.pendingSearchFocus = false;
    this.searchContentVisible = false;
    this.searchController.stopEditing();
    this.query = ''; this.searching = false;
    this.homeTabsController?.applyMiniBarStyle(hds.HdsBarStyle.COLLAPSE);
  }

  private overviewRows(): OverviewRow[] {
    const bills = this.data.bills.filter((bill: Bill) => bill.buildingId === this.buildingId && bill.month === this.overviewMonth);
    const rows = this.data.rooms.filter((room: Room) => room.buildingId === this.buildingId).map((room: Room): OverviewRow => {
      const row = new OverviewRow(); row.id = room.id; row.number = room.number;
      row.bill = bills.find((bill: Bill) => bill.roomId === room.id);
      return row;
    });
    bills.forEach((bill: Bill) => {
      if (!rows.some((row: OverviewRow) => row.id === bill.roomId)) {
        const row = new OverviewRow(); row.id = bill.roomId; row.number = bill.roomNumber; row.bill = bill; rows.push(row);
      }
    });
    return rows.filter((row: OverviewRow) => row.number.toLowerCase().includes(this.query.trim().toLowerCase()))
      .sort((a: OverviewRow, b: OverviewRow) => Number(a.bill?.paid ?? false) - Number(b.bill?.paid ?? false) || compareRoomNumbers(a.number, b.number));
  }

  private open(name: string, id: string = '', title: string = ''): void {
    const route = new PageRoute(); route.id = id; route.title = title; route.buildingId = this.buildingId;
    this.detailOpen = true;
    this.paths.pushPathByName(name, route);
  }

  private editEntry(month: string, number: string, buildingId: string): void {
    this.buildingId = buildingId; this.readingMonth = shiftMonth(month, -1); this.query = number; this.tab = 1;
    this.detailOpen = false; this.paths.clear();
  }

  private shift(reading: boolean, delta: number): void {
    try {
      if (reading) { this.selectReadingMonth(shiftMonth(this.readingMonth, delta)); }
      else { this.overviewMonth = shiftMonth(this.overviewMonth, delta); }
    } catch (error) { this.message = (error as Error).message; }
  }

  private chooseMonth(reading: boolean): void {
    const month = reading ? this.readingMonth : this.overviewMonth;
    this.getUIContext().showDatePickerDialog({
      selected: new Date(Number(month.slice(0, 4)), Number(month.slice(5)) - 1, 1),
      start: new Date(2000, 0, 1), end: new Date(2100, 11, 31),
      onAccept: (value: DatePickerResult) => {
        if (value.year !== undefined && value.month !== undefined) {
          const next = String(value.year).padStart(4, '0') + '-' + String(value.month + 1).padStart(2, '0');
          if (reading) { this.selectReadingMonth(next); } else { this.overviewMonth = next; }
        }
      }
    });
  }

  private selectReadingMonth(month: string): void {
    this.readingMonth = month;
    this.missingRentMonths = buildingMissingMonths(this.data, this.buildingId, this.billMonth());
    if (this.missingRentMonths.length > 0) { this.confirmMerge(); }
  }

  private confirmMerge(): void {
    const months = this.missingRentMonths.slice();
    const buildingId = this.buildingId;
    const billMonth = this.billMonth();
    this.getUIContext().showAlertDialog({
      title: '检测到漏月',
      message: months.map((month: string) => monthTitle(month)).join('、') +
        '未出账。是否把这些月份的房租加入当前楼栋各房间的本期账单？水电仍按实际读数计算。',
      primaryButton: { value: '不合并', action: () => {} },
      secondaryButton: { value: '合并房租', action: () => { this.mergeRent(buildingId, billMonth, months); } }
    });
  }

  private async mergeRent(buildingId: string, month: string, months: string[]): Promise<void> {
    this.busy = true;
    try {
      await StoreSession.entries!.mergeBuildingRent(buildingId, month, months, () => util.generateRandomUUID());
      this.missingRentMonths = [];
    } catch (error) { this.message = (error as Error).message; }
    finally { this.reload(); this.entryRevision++; this.busy = false; }
  }

  private async markPaid(bill: Bill): Promise<void> {
    this.busy = true;
    try { await StoreSession.store!.setBillPaid(bill.id, !bill.paid, today()); this.reload(); }
    catch (error) { this.message = (error as Error).message; }
    finally { this.busy = false; }
  }

  private confirmAllPaid(): void {
    const buildingId = this.buildingId;
    const month = this.overviewMonth;
    const paid = this.summary().paidCount < this.summary().billCount;
    this.getUIContext().showAlertDialog({
      title: paid ? '标记全部已收？' : '标记全部未收？',
      message: '将当前楼栋 ' + monthTitle(month) + (paid ? ' 的未收账单标记为已收，收款日期为今天。' : ' 的全部账单标记为未收，并清除收款日期。'),
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: paid ? '确认已收' : '确认未收', action: () => { this.markAllPaid(buildingId, month, paid); } }
    });
  }

  private async markAllPaid(buildingId: string, month: string, paid: boolean): Promise<void> {
    this.busy = true;
    try { await StoreSession.store!.markMonthPaid(buildingId, month, today(), paid); this.reload(); }
    catch (error) { this.message = (error as Error).message; }
    finally { this.busy = false; }
  }

  private async exportReceipts(): Promise<void> {
    if (this.busy) { return; }
    const buildingId = this.buildingId; const month = this.billMonth();
    this.busy = true; this.exporting = true; this.cancelExport = false; this.message = ''; this.exportStatus = '准备生成收据…';
    try {
      await StoreSession.store!.flush();
      const data = StoreSession.store!.snapshot().data;
      const building = data.buildings.find((b: Building) => b.id === buildingId);
      if (!building) { throw new Error('楼栋不存在'); }
      const bills = data.bills.filter((b: Bill) => b.buildingId === buildingId && b.month === month);
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const result = await runReceiptBatch(bills,
        (bill: Bill) => receiptPng(context,bill,building,building.receiptTemplate ?? data.receiptTemplate),
        (paths: string[]) => saveReceiptImages(context,paths),
        (path: string) => fs.unlink(path), () => this.cancelExport,
        (complete: number,total: number) => { this.exportStatus = building.name + ' ' + month + ' · 已生成 ' + complete + ' / ' + total + ' 张'; });
      this.exportStatus = result.cancelled ? '已停止生成，未保存到相册' : building.name + ' ' + month + ' · 已保存 ' + result.saved + ' / ' + result.total + ' 张收据';
    } catch (e) { this.exportStatus = ''; this.message = '导出未完成：' + (e as Error).message; }
    finally { this.busy = false; this.exporting = false; }
  }

  @Builder
  destination(name: string, param: Object) {
    if (name === 'more') {
      this.morePage()
    } else if (name === 'settings') {
      SettingsPage()
    } else if (name === 'about') {
      AboutPage()
    } else if (name === 'archive') {
      ArchivePage({ buildingId: (param as PageRoute).buildingId })
    } else if (name === 'template') {
      TemplatePage({ buildingId: (param as PageRoute).buildingId, onSaved: () => this.reload() })
    } else if (name === 'receipt') {
      ReceiptPage({ billId: (param as PageRoute).id })
    } else if (name === 'backup') {
      BackupPage({ onSaved: () => { this.reload(); this.entryRevision++; } })
    } else if (name === 'building') {
      BuildingEditor({ original: this.data.buildings.find((building: Building) => building.id === (param as PageRoute).id),
        paths: this.paths, onSaved: () => this.reload() })
    } else if (name === 'room') {
      RoomEditor({ original: this.data.rooms.find((room: Room) => room.id === (param as PageRoute).id),
        buildingId: (param as PageRoute).buildingId, paths: this.paths, onSaved: () => this.reload() })
    } else if (name === 'history') {
      RoomHistory({ roomId: (param as PageRoute).id, roomNumber: (param as PageRoute).title,
        buildingId: (param as PageRoute).buildingId, paths: this.paths })
    } else if (name === 'bill') {
      BillDetail({ billId: (param as PageRoute).id, onReceipt: (id: string) => this.open('receipt',id), onSaved: () => this.reload(),
        onEdit: (bill: Bill) => this.editEntry(bill.month, bill.roomNumber, bill.buildingId) })
    }
  }

  @Builder
  iconButton(icon: Resource, label: string, action: () => void) {
    Button() {
      SymbolGlyph(icon).fontSize(20 * this.uiScale).fontColor([$r('sys.color.ohos_id_color_emphasize')])
    }.type(ButtonType.Normal).buttonStyle(ButtonStyleMode.TEXTUAL).backgroundColor(Color.Transparent)
      .borderRadius(14).width(48 * this.uiScale).height(48 * this.uiScale)
      .accessibilityText(label).onClick(action)
  }

  @Builder
  actionRow(icon: Resource, title: string, subtitle: string, action: () => void) {
    Button() {
      Row({ space: 14 }) {
        SymbolGlyph(icon).fontSize(22 * this.uiScale).fontColor([$r('sys.color.ohos_id_color_emphasize')])
          .width(32)
        Column({ space: 5 }) {
          Text(title).fontSize(16 * this.uiScale).fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.ohos_id_color_text_primary')).width('100%')
          if (subtitle) {
            Text(subtitle).fontSize(12 * this.uiScale).fontColor($r('sys.color.ohos_id_color_text_secondary')).width('100%')
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(12).fontColor([$r('sys.color.ohos_id_color_text_secondary')])
      }.width('100%').padding({ left: 16, right: 16, top: 15, bottom: 15 })
    }.type(ButtonType.Normal).buttonStyle(ButtonStyleMode.NORMAL).backgroundColor(Color.Transparent)
      .borderRadius(18).width('100%').accessibilityText(title).onClick(action)
  }

  private moreScroller: Scroller = new Scroller();

  @Builder
  moreContent() {
      Scroll(this.moreScroller) {
        Column({ space: 24 }) {
          Column() {
            this.actionRow($r('sys.symbol.gearshape'), '外观设置', '配色、界面大小与动画', () => this.open('settings'))
            if (this.buildingId) {
              Divider().margin({ left: 62 }).width('80%').opacity(0.15)
              this.actionRow($r('sys.symbol.doc_text'), '收据模板', '当前楼栋的收据样式', () => this.open('template'))
            }
          }.width('100%').borderRadius(20).backgroundColor($r('app.color.surface'))
          Column() {
            this.actionRow($r('sys.symbol.info_circle'), '关于租簿', '版本、隐私与开源许可', () => this.open('about'))
          }.width('100%').borderRadius(20).backgroundColor($r('app.color.surface'))
          Text('所有数据仅保存在本机').fontSize(13 * this.uiScale).fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }.padding(16).width('100%').constraintSize({ maxWidth: 760 })
      }.clip(!supportsImmersiveNavigation()).width('100%').height('100%').align(Alignment.Top)
  }

  @Builder
  morePage() {
    if (supportsImmersiveNavigation()) {
      HdsNavDestination() { this.moreContent() }
        .bindToScrollable([this.moreScroller])
        .titleBar(gradientTitleBar('更多设置')).systemBarStyle({ statusBarContentColor: this.statusBarContentColor },
          { statusBarContentColor: this.statusBarContentColor }).titleMode(HdsNavDestinationTitleMode.MINI).backgroundColor($r('app.color.page_background'))
    } else {
      NavDestination() { this.moreContent() }.title('更多设置').backgroundColor($r('app.color.page_background'))
    }
  }

  @Builder
  monthBar(reading: boolean) {
    Row({ space: 4 }) {
      this.iconButton($r('sys.symbol.chevron_left'), '上一月', () => this.shift(reading, -1))
      Button() {
        Column({ space: 5 }) {
          Text(reading ? Number(this.billMonth().slice(0, 4)) + '年' + Number(this.billMonth().slice(5)) + '月开单' : monthTitle(this.overviewMonth) + '房租')
            .fontSize(19 * this.uiScale).fontWeight(FontWeight.Bold).fontColor($r('sys.color.ohos_id_color_text_primary'))
            .maxLines(1)
          if (!reading) {
            Text('含 ' + monthTitle(shiftMonth(this.overviewMonth, -1)) + ' 水电费')
              .fontSize(12 * this.uiScale).fontColor($r('sys.color.ohos_id_color_text_secondary'))
          }
        }
      }.type(ButtonType.Normal).buttonStyle(ButtonStyleMode.TEXTUAL).backgroundColor(Color.Transparent)
        .layoutWeight(1).height(70 * this.uiScale).accessibilityText('选择月份').onClick(() => this.chooseMonth(reading))
      this.iconButton($r('sys.symbol.chevron_right'), '下一月', () => this.shift(reading, 1))
    }.width('100%').padding(6).borderRadius(20).backgroundColor($r('app.color.surface'))
  }

  @Builder
  emptyRooms() {
    Column({ space: 16 }) {
      SymbolGlyph($r('sys.symbol.house')).fontSize(36).fontColor([$r('sys.color.ohos_id_color_text_secondary')])
      Text(this.query.trim() ? '没有匹配的房间' : '还没有房间').fontSize(18 * this.uiScale)
      if (this.query.trim()) { Button('清除搜索').onClick(() => { this.query = ''; }) }
      else { Button('新增房间').height(48 * this.uiScale).onClick(() => this.open('room')) }
    }.width('100%').padding(24)
  }

  @Builder
  statistic(value: string, label: string) {
    Column({ space: 6 }) {
      Text(value).fontSize(19 * this.uiScale).fontWeight(FontWeight.Bold)
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(label).fontSize(12 * this.uiScale).fontColor($r('sys.color.ohos_id_color_text_secondary'))
    }.layoutWeight(1).padding({ top: 14, bottom: 14 }).borderRadius(16).backgroundColor($r('app.color.surface'))
  }

  @Builder
  overview() {
    Scroll(this.overviewScroller) {
      Column({ space: 14 }) {
        this.monthBar(false)
        Row({ space: 10 }) {
          this.statistic(String(this.summary().roomCount), '房间')
          this.statistic(String(this.summary().billCount), '已出账')
          this.statistic('¥' + this.summary().expected, '本月应收')
        }.width('100%')
        Column({ space: 10 }) {
          Row() {
            Text('本月已收').fontSize(14 * this.uiScale).fontColor($r('sys.color.ohos_id_color_text_secondary')).layoutWeight(1)
            Text(this.summary().paidCount + ' / ' + this.summary().billCount + ' 单').fontSize(13 * this.uiScale)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          }.width('100%')
          Text('¥ ' + this.summary().received).fontSize(30 * this.uiScale).fontWeight(FontWeight.Bold).width('100%')
          Text('水费 ¥' + this.summary().waterReceived + '  ·  电费 ¥' + this.summary().electricityReceived +
            '  ·  出租 ' + this.summary().occupiedCount + ' 间').fontSize(12 * this.uiScale)
            .fontColor($r('sys.color.ohos_id_color_text_secondary')).width('100%')
          if (this.summary().billCount > 0) {
            Divider().opacity(0.12)
            Button(this.summary().paidCount === this.summary().billCount ? '标记本月全部未收' : '标记本月全部已收')
              .type(ButtonType.Normal).buttonStyle(ButtonStyleMode.TEXTUAL).width('100%').height(44 * this.uiScale)
              .enabled(!this.busy).onClick(() => this.confirmAllPaid())
          }
        }.padding(18).borderRadius(20).backgroundColor($r('app.color.surface')).width('100%')
        Text('房间账单').fontSize(15 * this.uiScale).fontWeight(FontWeight.Medium).width('100%').margin({ top: 6 })
        if (this.overviewRows().length === 0) { this.emptyRooms() }
        GridRow({ columns: this.roomColumns(), gutter: 16 }) {
          ForEach(this.overviewRows(), (row: OverviewRow) => {
            GridCol() {
              Column({ space: 0 }) {
                Button() {
                  Row({ space: 12 }) {
                    SymbolGlyph($r('sys.symbol.house')).fontSize(22 * this.uiScale)
                      .fontColor([$r('sys.color.ohos_id_color_emphasize')])
                    Column({ space: 5 }) {
                      Text(row.number + ' 房').fontSize(18 * this.uiScale).fontWeight(FontWeight.Medium)
                        .fontColor($r('sys.color.ohos_id_color_text_primary')).width('100%')
                      Text(row.bill ? (row.bill.paid ? '已收 · ' + (row.bill.paidDate ?? '') : '等待收款') : '本月尚未出账')
                        .fontSize(12 * this.uiScale).fontColor($r('sys.color.ohos_id_color_text_secondary')).width('100%')
                    }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                    Text(row.bill ? '¥ ' + row.bill.total : '去录入').fontSize(18 * this.uiScale).fontWeight(FontWeight.Medium)
                      .fontColor($r('sys.color.ohos_id_color_text_primary'))
                    SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(12).fontColor([$r('sys.color.ohos_id_color_text_secondary')])
                  }.width('100%').padding(16)
                }.type(ButtonType.Normal).buttonStyle(ButtonStyleMode.NORMAL).backgroundColor(Color.Transparent).borderRadius(20).width('100%')
                  .accessibilityText(row.number + ' 房 · 账单详情')
                  .onClick(() => { if (row.bill) { this.open('bill', row.bill.id); } else { this.editEntry(this.overviewMonth, row.number, this.buildingId); } })
                Row() {
                  Button('历史账单').type(ButtonType.Normal).buttonStyle(ButtonStyleMode.TEXTUAL).height(44 * this.uiScale)
                    .onClick(() => this.open('history', row.id, row.number))
                  Blank()
                  if (row.bill) {
                    Button(row.bill.paid ? '改为未收' : '标记已收').type(ButtonType.Normal).buttonStyle(ButtonStyleMode.TEXTUAL)
                      .height(44 * this.uiScale).enabled(!this.busy).onClick(() => { this.markPaid(row.bill!); })
                  }
                }.width('100%').padding({ left: 6, right: 6, bottom: 4 })
              }.width('100%').borderRadius(20).backgroundColor($r('app.color.surface'))
            }
          }, (row: OverviewRow) => row.id + ':' + row.number + ':' + JSON.stringify(row.bill))
        }.width('100%')
      }.padding({ left: this.pageMargin(), right: this.pageMargin(), top: 16, bottom: this.immersiveNavigation ? 96 : 16 }).width(this.pageWidth())
    }.clip(!supportsImmersiveNavigation()).width('100%').height('100%').align(Alignment.Top)
  }

  @Builder
  entry() {
    Scroll(this.entryScroller) {
      Column({ space: 14 }) {
        this.monthBar(true)
        Row({ space: 8 }) {
          Text('账单日期 ' + this.billMonth() + '-01').fontSize(12 * this.uiScale)
            .fontColor($r('sys.color.ohos_id_color_text_secondary')).layoutWeight(1)
          Button('导出收据').type(ButtonType.Normal).buttonStyle(ButtonStyleMode.TEXTUAL).height(48 * this.uiScale)
            .accessibilityText('导出本月收据到相册')
            .enabled(!this.busy && this.data.bills.some((b: Bill) => b.buildingId === this.buildingId && b.month === this.billMonth()))
            .onClick(() => this.exportReceipts())
        }.width('100%')
        if (this.missingRentMonths.length > 0) {
          Button('补收漏月房租').type(ButtonType.Normal).buttonStyle(ButtonStyleMode.NORMAL).borderRadius(16)
            .width('100%').height(48 * this.uiScale).enabled(!this.busy).onClick(() => this.confirmMerge())
        }
        if (this.rooms().length === 0) { this.emptyRooms() }
        GridRow({ columns: this.roomColumns(), gutter: 16 }) {
          ForEach(this.rooms(), (room: Room) => {
            GridCol() {
              EntryCard({ room: room, settings: this.building()!.settings, month: this.billMonth(), onSaved: () => this.reload() })
                .enabled(!this.busy)
            }
          }, (room: Room) => room.buildingId + ':' + room.id + ':' + this.billMonth() + ':' + JSON.stringify(room) + ':' + JSON.stringify(this.building()?.settings) + ':' + this.entryRevision)
        }.width('100%')
      }.padding({ left: this.pageMargin(), right: this.pageMargin(), top: 16, bottom: this.immersiveNavigation ? 96 : 16 }).width(this.pageWidth())
    }.clip(!supportsImmersiveNavigation()).width('100%').height('100%').align(Alignment.Top)
  }

  @Builder
  roomsPage() {
    Scroll(this.roomsScroller) {
      Column({ space: 14 }) {
        Column() {
          Row({ space: 8 }) {
            Column({ space: 5 }) {
              Text(this.building()?.name ?? '').fontSize(21 * this.uiScale).fontWeight(FontWeight.Bold).width('100%')
              Text('当前楼栋').fontSize(12 * this.uiScale).fontColor($r('sys.color.ohos_id_color_text_secondary')).width('100%')
            }.layoutWeight(1)
            this.iconButton($r('sys.symbol.plus'), '新增楼栋', () => this.open('building'))
          }.padding({ left: 16, right: 8, top: 16, bottom: 8 }).width('100%')
          this.actionRow($r('sys.symbol.gearshape'), '楼栋与默认单价',
            '水 ¥' + (this.building()?.settings.defaultWaterRate ?? '') + ' / 吨  ·  电 ¥' + (this.building()?.settings.defaultElectricityRate ?? '') + ' / 度',
            () => this.open('building', this.buildingId))
        }.width('100%').borderRadius(20).backgroundColor($r('app.color.surface'))
        Column() {
          this.actionRow($r('sys.symbol.doc_text'), '房东留档 PDF', '按月份导出账单汇总', () => this.open('archive'))
          Divider().margin({ left: 62 }).width('80%').opacity(0.15)
          this.actionRow($r('sys.symbol.folder'), '备份与恢复', '完整备份 · 兼容 Android / iOS', () => this.open('backup'))
        }.width('100%').borderRadius(20).backgroundColor($r('app.color.surface'))
        Row() {
          Text('房间（' + this.rooms().length + '）').fontSize(16 * this.uiScale).fontWeight(FontWeight.Medium).layoutWeight(1)
          Button('新增房间').type(ButtonType.Normal).buttonStyle(ButtonStyleMode.TEXTUAL).height(48 * this.uiScale)
            .onClick(() => this.open('room'))
        }.width('100%')
        if (this.rooms().length === 0) { this.emptyRooms() }
        GridRow({ columns: this.roomColumns(), gutter: 16 }) {
          ForEach(this.rooms(), (room: Room) => {
            GridCol() {
              Row({ space: 0 }) {
                Button() {
                  Row({ space: 12 }) {
                    SymbolGlyph($r('sys.symbol.house')).fontSize(22 * this.uiScale).fontColor([$r('sys.color.ohos_id_color_emphasize')])
                    Column({ space: 6 }) {
                      Row({ space: 8 }) {
                        Text(room.number + ' 房').fontSize(18 * this.uiScale).fontWeight(FontWeight.Medium)
                          .fontColor($r('sys.color.ohos_id_color_text_primary'))
                        Text(room.occupied ? '已出租' : '空置').fontSize(11 * this.uiScale)
                          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                      }
                      Text('月租 ¥' + room.rent).fontSize(14 * this.uiScale).fontColor($r('sys.color.ohos_id_color_text_secondary'))
                      Text('押金 ¥' + room.depositAmount + ' · ' +
                        (room.depositStatus === 'COLLECTED' ? '已收' : room.depositStatus === 'REFUNDED' ? '已退' : '未收'))
                        .fontSize(12 * this.uiScale).fontColor($r('sys.color.ohos_id_color_text_secondary'))
                    }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                    SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(12).fontColor([$r('sys.color.ohos_id_color_text_secondary')])
                  }.width('100%').padding(16)
                }.type(ButtonType.Normal).buttonStyle(ButtonStyleMode.NORMAL).backgroundColor(Color.Transparent)
                  .borderRadius(20).layoutWeight(1).accessibilityText('编辑 ' + room.number + ' 房').onClick(() => this.open('room', room.id))
                this.iconButton($r('sys.symbol.doc_text'), room.number + ' 房历史账单', () => this.open('history', room.id, room.number))
              }.width('100%').padding({ right: 6 }).borderRadius(20).backgroundColor($r('app.color.surface'))
            }
          }, (room: Room) => room.id + JSON.stringify(room))
        }.width('100%')
      }.padding({ left: this.pageMargin(), right: this.pageMargin(), top: 16, bottom: this.immersiveNavigation ? 96 : 16 }).width(this.pageWidth())
    }.clip(!supportsImmersiveNavigation()).width('100%').height('100%').align(Alignment.Top)
  }

  @Builder
  homeTitle() {
    Row({ space: 16 }) {
      Text(this.tab === 0 ? '房租概览' : this.tab === 1 ? '抄表录入' : '房间管理').fontColor($r('app.color.navigation_icon')).fontSize(24 * this.uiScale).fontWeight(FontWeight.Bold).layoutWeight(1).maxLines(1).minFontSize(18).maxFontSize(24 * this.uiScale)
      if (this.data.buildings.length > 0) {
        Select(this.data.buildings.map((building: Building): SelectOption => { return { value: building.name }; }))
          .value(this.building()?.name ?? '').selected(this.data.buildings.findIndex((building: Building) => building.id === this.buildingId))
          .onSelect((index: number) => {
            this.buildingId = this.data.buildings[index].id; this.query = '';
            if (this.tab === 1) { this.selectReadingMonth(this.readingMonth); }
          })
          .enabled(!this.busy).accessibilityText('切换楼栋').space(8)
          .constraintSize({ maxWidth: Math.min(160, this.contentWidth * 0.34) })
      }
      if (!this.immersiveNavigation) {
        this.iconButton($r('sys.symbol.gearshape'), '更多设置', () => this.open('more'))
      }
    // Reserve the native menu's 40vp button, 16vp edge inset and 8vp control gap.
    }.width('100%').padding({ left: 20, right: this.immersiveNavigation ? 64 : 8, top: 8, bottom: this.immersiveNavigation ? 8 : 4 })
  }

  private searchBarOpen(): boolean {
    return this.searching || this.miniBarExpanded || this.contentWidth >= 600;
  }

  @Builder
  nativeSearchBar() {
    Stack({ alignContent: Alignment.Start }) {
      Row({ space: 4 }) {
        Search({ value: this.query, placeholder: '查找房间', controller: this.searchController })
          .id('nativeRoomSearch').layoutWeight(1).height('100%').backgroundColor(Color.Transparent)
          .searchIcon({ size: 0, color: Color.Transparent })
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .textFont({ size: 16 * this.uiScale, weight: FontWeight.Regular })
          .placeholderFont({ size: 16 * this.uiScale, weight: FontWeight.Regular })
          .placeholderColor($r('sys.color.ohos_id_color_text_secondary'))
          .focusable(this.searchContentVisible).enableKeyboardOnFocus(true)
          .onAreaChange(() => this.focusNativeSearch())
          .onEditChange((editing: boolean) => { if (editing) { this.searching = true; } })
          .onChange((value: string) => { this.query = value; })
        Button('取消').type(ButtonType.Normal).buttonStyle(ButtonStyleMode.TEXTUAL)
          .fontSize(16 * this.uiScale).fontWeight(FontWeight.Regular)
          .height(48).accessibilityText('取消搜索')
          .onClick(() => this.endNativeSearch())
      }.width('100%').height('100%').padding({ left: 40, right: 8 })
        .visibility(this.searchContentVisible ? Visibility.Visible : Visibility.Hidden)
      // A 24vp symbol at x=16 is centered in the native 56vp collapsed minibar.
      SymbolGlyph($r('sys.symbol.magnifyingglass')).fontSize(24).width(24).height(24)
        .fontColor([$r('sys.color.ohos_id_color_text_secondary')]).margin({ left: 16 })
        .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      Button({ type: ButtonType.Circle }) {}
        .width('100%').height('100%').backgroundColor(Color.Transparent)
        .visibility(this.searchBarOpen() ? Visibility.Hidden : Visibility.Visible)
        .accessibilityText('搜索房间').enabled(!this.busy)
        .onClick(() => this.beginNativeSearch())
    }.width('100%').height('100%').clip(true)
  }

  @Builder
  nativeHomeTabs() {
    HdsTabs({ barPosition: BarPosition.End, index: this.tab, controller: this.homeTabsController }) {
      TabContent() { this.overview() }.clip(false)
        .tabBar(BottomTabBarStyle.of({ normal: new SymbolGlyphModifier($r('sys.symbol.house_fill')),
          selected: new SymbolGlyphModifier($r('sys.symbol.house_fill')) }, '概览'))
      TabContent() { this.entry() }.clip(false)
        .tabBar(BottomTabBarStyle.of({ normal: new SymbolGlyphModifier($r('sys.symbol.square_and_pencil_fill')),
          selected: new SymbolGlyphModifier($r('sys.symbol.square_and_pencil_fill')) }, '录入'))
      TabContent() { this.roomsPage() }.clip(false)
        .tabBar(BottomTabBarStyle.of({ normal: new SymbolGlyphModifier($r('sys.symbol.square_fill_grid_2x2')),
          selected: new SymbolGlyphModifier($r('sys.symbol.square_fill_grid_2x2')) }, '房间'))
    }.width('100%').layoutWeight(1).clip(false).barOverlap(true).barHeight(56).scrollable(false)
      .animationDuration(this.animations ? 300 : 0)
      .barFloatingStyle({
        barWidth: { smallWidth: this.compactTabWidth(), mediumWidth: 248, largeWidth: 272 },
        barSideMargin: this.tabSideMargin(),
        barBottomMargin: 8,
        adaptToHandedness: false,
        // 56vp native bar + 8vp bottom margin + 16vp transition above the bar.
        gradientMask: { maskColor: $r('app.color.page_background'), maskHeight: 80 },
        systemMaterialEffect: { materialType: 101,
          materialLevel: 10 },
        thermoCtrl: true,
        miniBar: {
          miniBarBuilder: () => { this.nativeSearchBar(); },
          miniBarWidth: { smallWidth: this.compactSearchWidth(), mediumWidth: 248, largeWidth: 272 },
          miniBarStyle: hds.HdsBarStyle.COLLAPSE,
          enableMiniBarBackground: true,
          onBarStyleChange: (miniStyle: hds.HdsBarStyle, tabStyle: hds.HdsBarStyle,
            miniWidth: number, tabWidth: number, mode: hds.HdsTabsBarChangeMode) => {
            this.miniBarExpanded = miniStyle === hds.HdsBarStyle.EXPAND;
            if (!this.miniBarExpanded) {
              this.pendingSearchFocus = false;
              this.searchController.stopEditing();
              this.searching = false;
            } else if (mode === hds.HdsTabsBarChangeMode.USER_CLICK) {
              this.pendingSearchFocus = true;
            }
            this.searchContentVisible = this.miniBarExpanded;
            if (this.miniBarExpanded) { this.focusNativeSearch(); }
          },
          onMiniBarAnimationEnd: (style: hds.HdsBarStyle) => {
            this.miniBarExpanded = style === hds.HdsBarStyle.EXPAND;
            this.searchContentVisible = this.miniBarExpanded;
            if (this.miniBarExpanded && this.pendingSearchFocus) {
              this.focusNativeSearch();
            }
          }
        }
      })
      .onTabBarClick((index: number) => {
        if (this.searching || this.pendingSearchFocus) {
          this.endNativeSearch();
        }
        if (index === this.tab) {
          const scroller = index === 0 ? this.overviewScroller : index === 1 ? this.entryScroller : this.roomsScroller;
          scroller.scrollEdge(Edge.Top);
        }
      })
      .onChange((index: number) => {
        this.tab = index; this.query = ''; this.searching = false;
        if (index === 1) { this.selectReadingMonth(this.readingMonth); }
      })
  }

  @Builder
  legacySearchBar() {
    Row() {
      Search({ value: this.query, placeholder: '查找房间', controller: this.searchController })
        .id('roomSearch').enableKeyboardOnFocus(true)
        .height(48 * this.uiScale).width('100%')
        .textFont({ size: 16 * this.uiScale, weight: FontWeight.Regular })
        .placeholderFont({ size: 16 * this.uiScale, weight: FontWeight.Regular })
        .cancelButton({ style: CancelButtonStyle.INPUT })
        .onEditChange((editing: boolean) => { this.searching = editing; })
        .onChange((value: string) => { this.query = value; })
    }.width('100%').padding({ left: this.pageMargin(), right: this.pageMargin(), top: 0, bottom: 8 })
  }

  @Builder
  homeContent() {
      Column() {
        if (StoreSession.error) {
          Text(StoreSession.error).fontSize(18 * this.uiScale).padding(24)
        } else {
          if (!this.immersiveNavigation) { this.homeTitle() }
          if (this.exportStatus) { Text(this.exportStatus).fontSize(14 * this.uiScale).fontColor($r('sys.color.ohos_id_color_text_secondary')).padding(12) }
          if (this.exporting) {
            Button(this.cancelExport ? '正在停止…' : '停止生成').height(48 * this.uiScale).enabled(!this.cancelExport).onClick(() => { this.cancelExport = true; })
          }
          if (this.message) { Text(this.message).fontSize(14 * this.uiScale).fontColor($r('app.color.danger')).padding(12) }
          if (this.data.buildings.length === 0) {
            Column({ space: 20 }) {
              Text('创建你的第一栋楼').fontSize(24 * this.uiScale)
              Text('设置水电单价，再添加房间开始记账。').fontSize(16 * this.uiScale)
              Button('新增楼栋').height(48 * this.uiScale).onClick(() => this.open('building'))
              Button('备份与恢复').type(ButtonType.Normal).buttonStyle(ButtonStyleMode.NORMAL).borderRadius(16).height(48 * this.uiScale).onClick(() => this.open('backup'))
            }.layoutWeight(1).justifyContent(FlexAlign.Center).width('100%').padding(24)
          } else {
            if (this.immersiveNavigation) {
              this.nativeHomeTabs()
            } else {
              this.legacySearchBar()
              Column() {
                if (this.tab === 0) { this.overview() }
                else if (this.tab === 1) { this.entry() }
                else { this.roomsPage() }
              }.layoutWeight(1).width('100%')
              Row({ space: 12 }) {
                  Tabs({ barPosition: BarPosition.End, index: this.tab }) {
                    TabContent() {}.tabBar(BottomTabBarStyle.of({ normal: new SymbolGlyphModifier($r('sys.symbol.house_fill')).fontColor([$r('sys.color.ohos_id_color_text_secondary')]), selected: new SymbolGlyphModifier($r('sys.symbol.house_fill')).fontColor([$r('sys.color.ohos_id_color_emphasize')]) }, '概览').labelStyle(this.immersiveNavigation ? { selectedColor: $r('sys.color.ohos_id_color_emphasize'), unselectedColor: $r('sys.color.ohos_id_color_text_secondary') } : {}).iconStyle({ selectedColor: $r('sys.color.ohos_id_color_emphasize'), unselectedColor: $r('sys.color.ohos_id_color_text_secondary') }))
                    TabContent() {}.tabBar(BottomTabBarStyle.of({ normal: new SymbolGlyphModifier($r('sys.symbol.square_and_pencil_fill')).fontColor([$r('sys.color.ohos_id_color_text_secondary')]), selected: new SymbolGlyphModifier($r('sys.symbol.square_and_pencil_fill')).fontColor([$r('sys.color.ohos_id_color_emphasize')]) }, '录入').labelStyle(this.immersiveNavigation ? { selectedColor: $r('sys.color.ohos_id_color_emphasize'), unselectedColor: $r('sys.color.ohos_id_color_text_secondary') } : {}).iconStyle({ selectedColor: $r('sys.color.ohos_id_color_emphasize'), unselectedColor: $r('sys.color.ohos_id_color_text_secondary') }))
                    TabContent() {}.tabBar(BottomTabBarStyle.of({ normal: new SymbolGlyphModifier($r('sys.symbol.square_fill_grid_2x2')).fontColor([$r('sys.color.ohos_id_color_text_secondary')]), selected: new SymbolGlyphModifier($r('sys.symbol.square_fill_grid_2x2')).fontColor([$r('sys.color.ohos_id_color_emphasize')]) }, '房间').labelStyle(this.immersiveNavigation ? { selectedColor: $r('sys.color.ohos_id_color_emphasize'), unselectedColor: $r('sys.color.ohos_id_color_text_secondary') } : {}).iconStyle({ selectedColor: $r('sys.color.ohos_id_color_emphasize'), unselectedColor: $r('sys.color.ohos_id_color_text_secondary') }))
                  }.layoutWeight(1).height(80 * this.uiScale).barHeight(64 * this.uiScale)
                    .enabled(!this.busy).scrollable(false).animationDuration(this.animations ? 300 : 0)
                    .onTabBarClick((index: number) => {
                  if (this.immersiveNavigation && index === this.tab) {
                    const scroller = index === 0 ? this.overviewScroller : index === 1 ? this.entryScroller : this.roomsScroller;
                    scroller.scrollEdge(Edge.Top);
                  }
                })
                    .onChange((index: number) => {
                  this.searchController.stopEditing();
                  this.tab = index; this.query = ''; this.searching = false;
                  if (index === 1) { this.selectReadingMonth(this.readingMonth); }
                })
              }.width('100%').padding({ left: 16, right: 16 }).constraintSize({ minHeight: 80 * this.uiScale })
            }

          }
        }
      }.width('100%').height('100%').align(Alignment.TopStart)
        .expandSafeArea(this.immersiveNavigation ? [] : [SafeAreaType.KEYBOARD], [SafeAreaEdge.BOTTOM])
        .onAreaChange((oldArea: Area, newArea: Area) => {
          const width = Number(newArea.width);
          if (Number.isFinite(width) && width > 0 && width !== this.contentWidth) { this.contentWidth = width; }
        })
  }

  build() {
    if (this.immersiveNavigation) {
      HdsNavigation(this.paths) { this.homeContent() }.titleBar(gradientTitleBar('', () => this.open('more'), () => { this.homeTitle(); }))
      .systemBarStyle({ statusBarContentColor: this.statusBarContentColor },
        { statusBarContentColor: this.statusBarContentColor }).titleMode(HdsNavigationTitleMode.MINI).hideBackButton(true)
      .bindToScrollable([this.tab === 0 ? this.overviewScroller : this.tab === 1 ? this.entryScroller : this.roomsScroller])
      .navDestination(this.destination).mode(this.detailOpen ? NavigationMode.Auto : NavigationMode.Stack)
      .navBarWidth(360).minContentWidth(360).width('100%').height('100%')
      .backgroundColor($r('app.color.page_background'))
    } else {
      Navigation(this.paths) { this.homeContent() }.hideTitleBar(!this.immersiveNavigation)
      .title(this.immersiveNavigation ? (this.tab === 0 ? '房租概览' : this.tab === 1 ? '抄表录入' : '房间管理') : '')
      .titleMode(NavigationTitleMode.Mini).hideBackButton(true)
      .menus(this.immersiveNavigation ? [{ value: '更多设置',
        symbolIcon: new SymbolGlyphModifier($r('sys.symbol.gearshape')),
        action: () => this.open('more') }] : [])
      .navDestination(this.destination).mode(this.detailOpen ? NavigationMode.Auto : NavigationMode.Stack)
      .navBarWidth(360).minContentWidth(360).width('100%').height('100%')
      .backgroundColor($r('app.color.page_background'))
    }
  }
}
