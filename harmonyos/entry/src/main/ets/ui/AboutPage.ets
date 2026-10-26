import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { supportsImmersiveNavigation, gradientTitleBar } from './ImmersiveNavigation';
import { util } from '@kit.ArkTS';
@Component
export struct AboutPage {
  @StorageLink('statusBarContentColor') statusBarContentColor: string = '#000000';
  @StorageLink('pageScale') uiScale: number = 1;
  @State license: string = '';
  @State message: string = '';
  private async showLicense(): Promise<void> {
    try {
      const bytes = await this.getUIContext().getHostContext()!.resourceManager.getRawFileContent('LICENSE.txt');
      const decoder = new util.TextDecoder(); this.license = decoder.decodeToString(bytes);
    } catch (e) { this.message = '许可文件读取失败'; }
  }
  private pageScroller: Scroller = new Scroller();

  @Builder
  pageContent() {
      Scroll(this.pageScroller) {
        Column({space:20}) {
          Text('租簿').fontSize(32 * this.uiScale).fontWeight(FontWeight.Bold).width('100%')
          Text('版本 1.3 · 原生 HarmonyOS').width('100%')
          Text('用于楼栋、房间、房租与水电账单管理，以及收据生成、备份和导出。').width('100%')
          Text('隐私说明').fontSize(22 * this.uiScale).width('100%')
          Text('全部业务数据保存在本机，无广告、无账号，无需联网。只有你主动保存、导出或分享时，数据才交给系统文件、相册或你选择的应用。卸载或清除应用数据会删除本地记录，请定期导出备份。').width('100%')
          Text('开源许可与致谢').fontSize(22 * this.uiScale).width('100%')
          Text('项目许可：GPL-3.0。允许依照许可使用、修改与再分发，不提供担保。发布时应提供对应版本完整源码及构建脚本。').width('100%')
          Text('鸿蒙客户端使用 ArkTS、ArkUI 和华为系统 SDK。没有引入 Android 版的 Compose、Miuix 或玻璃控件运行依赖；业务模型与备份格式沿用本项目。').width('100%')
          Button(this.license ? '收起许可全文' : '查看 GPL-3.0 全文').width('100%').height(48 * this.uiScale).onClick(() => { if (this.license) { this.license = ''; } else { this.showLicense(); } })
          if (this.license) { Text(this.license).fontSize(14 * this.uiScale).width('100%') }
          if (this.message) { Text(this.message).width('100%') }
        }.padding(24).width('100%')
      }.clip(!supportsImmersiveNavigation()).width('100%').height('100%').align(Alignment.TopStart)
  }

  build() {
    if (supportsImmersiveNavigation()) {
      HdsNavDestination() { this.pageContent() }
        .bindToScrollable([this.pageScroller])
        .titleBar(gradientTitleBar('关于租簿')).systemBarStyle({ statusBarContentColor: this.statusBarContentColor },
          { statusBarContentColor: this.statusBarContentColor }).titleMode(HdsNavDestinationTitleMode.MINI).backgroundColor($r('app.color.page_background'))
    } else {
      NavDestination() { this.pageContent() }.title('关于租簿').backgroundColor($r('app.color.page_background'))
    }
  }
}
