import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { supportsImmersiveNavigation, gradientTitleBar } from './ImmersiveNavigation';
import { common } from '@kit.AbilityKit';
import { AppData } from '../model/Models';
import { StoreSession } from '../data/StoreSession';
import { EntryWorkflow } from '../data/EntryWorkflow';
import { BackupService } from '../data/BackupService';

@Component
export struct BackupPage {
  @StorageLink('statusBarContentColor') statusBarContentColor: string = '#000000';
  @StorageLink('pageScale') uiScale: number = 1;
  onSaved: () => void = () => {};
  @State busy: boolean = false;
  @State message: string = '';
  @State pending: AppData | undefined = undefined;
  private context(): common.UIAbilityContext { return this.getUIContext().getHostContext() as common.UIAbilityContext; }
  private async save(): Promise<void> {
    this.busy = true; this.message = '';
    try {
      await StoreSession.store!.flush();
      if (await BackupService.save(this.context(),StoreSession.store!.snapshot().data)) { this.message = 'ZIP 备份已保存'; }
    } catch (e) { this.message = '导出失败：' + (e as Error).message; }
    finally { this.busy = false; }
  }
  private async select(): Promise<void> {
    this.busy = true; this.message = ''; this.pending = undefined;
    try { this.pending = await BackupService.select(this.context()); }
    catch (e) { this.message = '导入失败：' + (e as Error).message + '。现有数据未改变。'; }
    finally { this.busy = false; }
  }
  private confirm(): void {
    const data = this.pending; if (!data) { return; }
    this.getUIContext().showAlertDialog({title:'覆盖当前全部数据？',
      message:'将恢复 ' + data.buildings.length + ' 栋楼、' + data.rooms.length + ' 个房间和 ' + data.bills.length + ' 张账单。当前全部楼栋、账单及未完成草稿将被替换。',
      primaryButton:{value:'取消',action:() => {}},
      secondaryButton:{value:'确认覆盖',action:() => { this.restore(data); }} });
  }
  private async restore(data: AppData): Promise<void> {
    this.busy = true;
    try {
      await StoreSession.store!.restore(data);
      StoreSession.entries = new EntryWorkflow(StoreSession.store!);
      this.pending = undefined; this.message = '恢复完成'; this.onSaved();
    } catch (e) { this.message = '恢复失败，原数据已保留：' + (e as Error).message; }
    finally { this.busy = false; }
  }
  private pageScroller: Scroller = new Scroller();

  @Builder
  pageContent() {
      Scroll(this.pageScroller) {
        Column({space:20}) {
          Text('备份包含全部楼栋、房间、收费设置、押金、历史账单及收据模板，可与 Android、iOS 版互换。未完成草稿和本机外观设置不包含在 ZIP 中。').fontSize(16 * this.uiScale).width('100%')
          Button('导出 ZIP').width('100%').height(48 * this.uiScale).enabled(!this.busy).onClick(() => this.save())
          Button('选择备份文件').type(ButtonType.Normal).buttonStyle(ButtonStyleMode.NORMAL).borderRadius(16).width('100%').height(48 * this.uiScale).enabled(!this.busy).onClick(() => this.select())
          if (this.pending) {
            Text('待恢复：' + this.pending.buildings.length + ' 栋楼 · ' + this.pending.rooms.length + ' 个房间 · ' + this.pending.bills.length + ' 张账单').width('100%').fontSize(18 * this.uiScale)
            Button('恢复此备份').width('100%').height(48 * this.uiScale).enabled(!this.busy).onClick(() => this.confirm())
            Button('取消恢复').type(ButtonType.Normal).buttonStyle(ButtonStyleMode.NORMAL).borderRadius(16).width('100%').height(48 * this.uiScale).enabled(!this.busy).onClick(() => { this.pending = undefined; })
          }
          if (this.busy) { LoadingProgress().width(36).height(36) }
          if (this.message) { Text(this.message).width('100%').fontSize(16 * this.uiScale) }
        }.padding(24).width('100%')
      }.clip(!supportsImmersiveNavigation()).width('100%').height('100%').align(Alignment.TopStart)
  }

  build() {
    if (supportsImmersiveNavigation()) {
      HdsNavDestination() { this.pageContent() }
        .bindToScrollable([this.pageScroller])
        .titleBar(gradientTitleBar('备份与恢复')).systemBarStyle({ statusBarContentColor: this.statusBarContentColor },
          { statusBarContentColor: this.statusBarContentColor }).titleMode(HdsNavDestinationTitleMode.MINI).onBackPressed(() => this.busy).backgroundColor($r('app.color.page_background'))
    } else {
      NavDestination() { this.pageContent() }.onBackPressed(() => this.busy).title('备份与恢复').backgroundColor($r('app.color.page_background'))
    }
  }
}
