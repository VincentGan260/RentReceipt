import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { supportsImmersiveNavigation, gradientTitleBar } from './ImmersiveNavigation';
import { common } from '@kit.AbilityKit';
import { Bill, Building, ReceiptTemplate } from '../model/Models';
import { StoreSession } from '../data/StoreSession';
import { receiptPng, saveReceiptImages, shareReceipt } from '../export/ReceiptService';

@Component
export struct ReceiptPage {
  @StorageLink('statusBarContentColor') statusBarContentColor: string = '#000000';
  @StorageLink('pageScale') uiScale: number = 1;
  billId: string = '';
  @State path: string = '';
  @State busy: boolean = false;
  @State message: string = '';
  aboutToAppear(): void { this.prepare(); }
  private context(): common.UIAbilityContext { return this.getUIContext().getHostContext() as common.UIAbilityContext; }
  private async prepare(): Promise<void> {
    this.busy = true;
    try {
      const data = StoreSession.store!.snapshot().data; const b = data.bills.find((b: Bill) => b.id === this.billId);
      const building = data.buildings.find((v: Building) => v.id === b?.buildingId);
      if (!b || !building) { throw new Error('账单或楼栋不存在'); }
      this.path = await receiptPng(this.context(),b,building,building.receiptTemplate ?? data.receiptTemplate);
    } catch (e) { this.message = (e as Error).message; }
    finally { this.busy = false; }
  }
  private async action(share: boolean): Promise<void> {
    this.busy = true; this.message = '';
    try {
      if (share) { await shareReceipt(this.context(),this.path); }
      else { const count = await saveReceiptImages(this.context(),[this.path]); this.message = count ? '已保存到相册' : '未保存'; }
    } catch (e) { this.message = (e as Error).message; }
    finally { this.busy = false; }
  }
  private pageScroller: Scroller = new Scroller();

  @Builder
  pageContent() {
      Scroll(this.pageScroller) {
        Column({space:16}) {
          if (this.path) {
            Image('file://'+this.path).width('100%').objectFit(ImageFit.Contain)
            Button('保存高清图片').type(ButtonType.Normal).borderRadius(16).width('100%').height(48 * this.uiScale).enabled(!this.busy).onClick(() => this.action(false))
            Button('分享图片').type(ButtonType.Normal).buttonStyle(ButtonStyleMode.NORMAL).borderRadius(16).width('100%').height(48 * this.uiScale).enabled(!this.busy).onClick(() => this.action(true))
          } else if (!this.busy) { Button('重新生成').type(ButtonType.Normal).borderRadius(16).onClick(() => this.prepare()) }
          if (this.busy) { LoadingProgress().width(36).height(36) }
          if (this.message) { Text(this.message).width('100%') }
        }.padding(16).width('100%')
      }.clip(!supportsImmersiveNavigation()).width('100%').height('100%').align(Alignment.TopStart)
  }

  build() {
    if (supportsImmersiveNavigation()) {
      HdsNavDestination() { this.pageContent() }
        .bindToScrollable([this.pageScroller])
        .titleBar(gradientTitleBar('房租单预览')).systemBarStyle({ statusBarContentColor: this.statusBarContentColor },
          { statusBarContentColor: this.statusBarContentColor }).titleMode(HdsNavDestinationTitleMode.MINI).backgroundColor($r('app.color.page_background'))
    } else {
      NavDestination() { this.pageContent() }.title('房租单预览').backgroundColor($r('app.color.page_background'))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
  }
}
