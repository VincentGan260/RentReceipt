import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { supportsImmersiveNavigation, gradientTitleBar } from './ImmersiveNavigation';
import { common } from '@kit.AbilityKit';
import { StoreSession } from '../data/StoreSession';
import { currentMonth } from '../model/UiLogic';
import { FormField } from './FormComponents';
import { archivePdf } from '../export/ArchiveService';
@Component
export struct ArchivePage {
  @StorageLink('statusBarContentColor') statusBarContentColor: string = '#000000';
  @StorageLink('pageScale') uiScale: number = 1;
  buildingId: string = '';
  @State start: string = currentMonth().slice(0,4)+'-01';
  @State end: string = currentMonth();
  @State busy: boolean = false;
  @State message: string = '';
  private async save(): Promise<void> {
    this.busy = true; this.message = '正在生成 PDF…';
    try {
      await StoreSession.store!.flush();
      const saved = await archivePdf(this.getUIContext().getHostContext() as common.UIAbilityContext,StoreSession.store!.snapshot().data,this.buildingId,this.start,this.end);
      this.message = saved ? 'PDF 已保存' : '已取消保存';
    } catch (e) { this.message = (e as Error).message; }
    finally { this.busy = false; }
  }
  private pageScroller: Scroller = new Scroller();

  @Builder
  pageContent() {
      Scroll(this.pageScroller) {
        Column({space:20}) {
          Text('按当前楼栋导出房东留档 PDF。每页最多 15 个房间、3 个月，包含出租情况、租金、押金、各月水电用量和金额汇总。').width('100%')
          FormField({label:'开始月份（YYYY-MM）',text:this.start,decimal:false,onEdit:(v: string) => { this.start = v; }})
          FormField({label:'结束月份（YYYY-MM）',text:this.end,decimal:false,onEdit:(v: string) => { this.end = v; }})
          Button('导出 PDF').width('100%').height(48 * this.uiScale).enabled(!this.busy).onClick(() => this.save())
          if (this.busy) { LoadingProgress().width(36).height(36) }
          if (this.message) { Text(this.message).width('100%') }
        }.padding(24).width('100%')
      }.clip(!supportsImmersiveNavigation()).width('100%').height('100%').align(Alignment.TopStart)
  }

  build() {
    if (supportsImmersiveNavigation()) {
      HdsNavDestination() { this.pageContent() }
        .bindToScrollable([this.pageScroller])
        .titleBar(gradientTitleBar('房东留档 PDF')).systemBarStyle({ statusBarContentColor: this.statusBarContentColor },
          { statusBarContentColor: this.statusBarContentColor }).titleMode(HdsNavDestinationTitleMode.MINI).onBackPressed(() => this.busy).backgroundColor($r('app.color.page_background'))
    } else {
      NavDestination() { this.pageContent() }.onBackPressed(() => this.busy).title('房东留档 PDF').backgroundColor($r('app.color.page_background'))
    }
  }
}
