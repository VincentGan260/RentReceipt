import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { supportsImmersiveNavigation, gradientTitleBar } from './ImmersiveNavigation';
import { Bill, CustomCharge } from '../model/Models';
import { monthTitle, today } from '../model/UiLogic';
import { Decimal } from '../model/Decimal';
import { StoreSession } from '../data/StoreSession';
import { DetailLine } from './FormComponents';

export class PageRoute {
  id: string = '';
  buildingId: string = '';
  title: string = '';
}

@Component
export struct RoomHistory {
  @StorageLink('statusBarContentColor') statusBarContentColor: string = '#000000';
  @StorageLink('pageScale') uiScale: number = 1;
  roomId: string = '';
  roomNumber: string = '';
  buildingId: string = '';
  paths: NavPathStack = new NavPathStack();
  @State bills: Bill[] = [];

  aboutToAppear(): void { this.reload(); }
  private reload(): void {
    this.bills = StoreSession.store!.snapshot().data.bills.filter((bill: Bill) =>
      bill.roomId === this.roomId && bill.buildingId === this.buildingId).sort((a: Bill, b: Bill) => a.month > b.month ? -1 : 1);
  }

  private open(bill: Bill): void {
    const route = new PageRoute(); route.id = bill.id; route.buildingId = bill.buildingId;
    this.paths.pushPathByName('bill', route);
  }

  private pageScroller: Scroller = new Scroller();

  @Builder
  pageContent() {
      Scroll(this.pageScroller) {
        Column({ space: 16 }) {
          if (this.bills.length === 0) {
            Text('还没有历史账单').fontSize(20 * this.uiScale).margin({ top: 32 })
            Text('在录入页填写水电读数后，账单会自动保存在这里。').fontSize(16 * this.uiScale)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          }
          ForEach(this.bills, (bill: Bill) => {
            Button() {
              Column({ space: 12 }) {
                Row({ space: 16 }) {
                  Text(monthTitle(bill.month)).fontSize(20 * this.uiScale).layoutWeight(1)
                  Text('¥ ' + bill.total).fontSize(22 * this.uiScale).fontWeight(FontWeight.Medium)
                }.width('100%')
                Text(bill.paid ? '已收 · ' + (bill.paidDate ?? '') : '未收').fontSize(14 * this.uiScale).width('100%')
                Text('水表 ' + bill.previousWater + ' → ' + bill.currentWater + '  ·  用量 ' +
                  (bill.waterUsage || Decimal.parse(bill.currentWater).subtract(Decimal.parse(bill.previousWater)).whole().toString()))
                  .fontSize(14 * this.uiScale).width('100%')
                Text('电表 ' + bill.previousElectricity + ' → ' + bill.currentElectricity + '  ·  用量 ' +
                  (bill.electricityUsage || Decimal.parse(bill.currentElectricity).subtract(Decimal.parse(bill.previousElectricity)).whole().toString()))
                  .fontSize(14 * this.uiScale).width('100%')
              }.padding(20).width('100%').alignItems(HorizontalAlign.Start)
            }.type(ButtonType.Normal).buttonStyle(ButtonStyleMode.NORMAL).borderRadius(16).width('100%').borderRadius(24)
              .backgroundColor($r('app.color.surface')).fontColor($r('sys.color.ohos_id_color_text_primary'))
              .onClick(() => this.open(bill))
          }, (bill: Bill) => bill.id + JSON.stringify(bill))
        }.padding(16).width('100%').constraintSize({ maxWidth: 760 }).alignItems(HorizontalAlign.Start)
      }.clip(!supportsImmersiveNavigation()).width('100%').height('100%').align(Alignment.TopStart)
  }

  build() {
    if (supportsImmersiveNavigation()) {
      HdsNavDestination() { this.pageContent() }
        .bindToScrollable([this.pageScroller])
        .titleBar(gradientTitleBar(this.roomNumber + ' 房 · 历史账单')).systemBarStyle({ statusBarContentColor: this.statusBarContentColor },
          { statusBarContentColor: this.statusBarContentColor }).titleMode(HdsNavDestinationTitleMode.MINI).onShown(() => this.reload())
      .backgroundColor($r('app.color.page_background'))
    } else {
      NavDestination() { this.pageContent() }.title(this.roomNumber + ' 房 · 历史账单').onShown(() => this.reload())
      .backgroundColor($r('app.color.page_background'))
    }
  }
}

@Component
export struct BillDetail {
  @StorageLink('statusBarContentColor') statusBarContentColor: string = '#000000';
  @StorageLink('pageScale') uiScale: number = 1;
  billId: string = '';
  onSaved: () => void = () => {};
  onEdit: (bill: Bill) => void = () => {};
  onReceipt: (id: string) => void = () => {};
  @State bill: Bill = new Bill();
  @State busy: boolean = false;
  @State message: string = '';
  @State canEdit: boolean = false;

  aboutToAppear(): void { this.reload(); }
  private reload(): void {
    const data = StoreSession.store!.snapshot().data;
    const bill = data.bills.find((value: Bill) => value.id === this.billId);
    if (bill) { this.bill = bill; this.canEdit = data.rooms.some((room) => room.id === bill.roomId); }
  }

  private async togglePaid(): Promise<void> {
    if (this.busy) { return; }
    this.busy = true;
    try { await StoreSession.store!.setBillPaid(this.billId, !this.bill.paid, today()); this.reload(); this.onSaved(); }
    catch (error) { this.message = (error as Error).message; }
    finally { this.busy = false; }
  }

  private pageScroller: Scroller = new Scroller();

  @Builder
  pageContent() {
      Scroll(this.pageScroller) {
        Column({ space: 20 }) {
          if (this.bill.id) {
            Column({ space: 16 }) {
              Text(this.bill.roomNumber + ' 房').fontSize(28 * this.uiScale).fontWeight(FontWeight.Medium).width('100%')
              Text(monthTitle(this.bill.month) + ' 房租单').fontSize(20 * this.uiScale).width('100%')
              Text('¥ ' + this.bill.total).fontSize(36 * this.uiScale).fontWeight(FontWeight.Bold).width('100%')
              DetailLine({ label: '账单日期', value: this.bill.createdDate })
              DetailLine({ label: '收租状态', value: this.bill.paid ? '已收 · ' + (this.bill.paidDate ?? '') : '未收' })
              if (this.bill.rentOnly) { Text('入住首月仅收房租').fontSize(16 * this.uiScale).width('100%') }
            }.padding(20).borderRadius(24).backgroundColor($r('app.color.surface')).width('100%')
            Column({ space: 16 }) {
              Text('费用明细').fontSize(20 * this.uiScale).fontWeight(FontWeight.Medium).width('100%')
              DetailLine({ label: '房租', value: '¥ ' + this.bill.rent })
              DetailLine({ label: '水表读数', value: this.bill.previousWater + ' → ' + this.bill.currentWater })
              DetailLine({ label: '水费用量 / 单价', value: (this.bill.waterUsage || '0') + ' 吨 / ¥ ' + this.bill.waterRate })
              DetailLine({ label: '水费', value: '¥ ' + this.bill.waterAmount })
              DetailLine({ label: '电表读数', value: this.bill.previousElectricity + ' → ' + this.bill.currentElectricity })
              DetailLine({ label: '电费用量 / 单价', value: (this.bill.electricityUsage || '0') + ' 度 / ¥ ' + this.bill.electricityRate })
              DetailLine({ label: '电费', value: '¥ ' + this.bill.electricityAmount })
              if (this.bill.managementRate) {
                DetailLine({ label: '公共服务费单价', value: '¥ ' + this.bill.managementRate + ' / 度' })
                DetailLine({ label: '公共服务费', value: '¥ ' + this.bill.managementAmount })
              }
              ForEach(this.bill.customCharges, (charge: CustomCharge) => {
                DetailLine({ label: charge.name, value: '¥ ' + charge.amount })
              }, (charge: CustomCharge, index: number) => String(index) + JSON.stringify(charge))
            }.padding(20).borderRadius(24).backgroundColor($r('app.color.surface')).width('100%')
            if (this.message) { Text(this.message).fontSize(16 * this.uiScale).fontColor($r('app.color.danger')).width('100%') }
            Button('预览房租单').width('100%').height(48 * this.uiScale).onClick(() => this.onReceipt(this.billId))
            Button(this.bill.paid ? '改为未收' : '标记已收').width('100%').height(48 * this.uiScale).enabled(!this.busy)
              .onClick(() => { this.togglePaid(); })
            if (this.canEdit) {
              Button('修改本月录入').type(ButtonType.Normal).buttonStyle(ButtonStyleMode.NORMAL).borderRadius(16).width('100%').height(48 * this.uiScale).enabled(!this.busy)
                .onClick(() => this.onEdit(this.bill))
            }
          } else { Text('账单不存在').fontSize(20 * this.uiScale) }
        }.padding(16).width('100%').constraintSize({ maxWidth: 760 }).alignItems(HorizontalAlign.Start)
      }.clip(!supportsImmersiveNavigation()).width('100%').height('100%').align(Alignment.TopStart)
  }

  build() {
    if (supportsImmersiveNavigation()) {
      HdsNavDestination() { this.pageContent() }
        .bindToScrollable([this.pageScroller])
        .titleBar(gradientTitleBar('账单详情')).systemBarStyle({ statusBarContentColor: this.statusBarContentColor },
          { statusBarContentColor: this.statusBarContentColor }).titleMode(HdsNavDestinationTitleMode.MINI).onBackPressed(() => this.busy).onShown(() => this.reload())
      .backgroundColor($r('app.color.page_background'))
    } else {
      NavDestination() { this.pageContent() }.title('账单详情').onBackPressed(() => this.busy).onShown(() => this.reload())
      .backgroundColor($r('app.color.page_background'))
    }
  }
}
