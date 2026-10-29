import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { supportsImmersiveNavigation, gradientTitleBar } from './ImmersiveNavigation';
import { common } from '@kit.AbilityKit';
import { Appearance } from '../data/Appearance';
@Component
export struct SettingsPage {
  @StorageLink('statusBarContentColor') statusBarContentColor: string = '#000000';
  @StorageLink('pageScale') uiScale: number = 1;
  @State mode: number = Appearance.mode;
  @State scaleValue: number = Appearance.scale;
  @State animations: boolean = Appearance.animations;
  @State message: string = '';
  private async change(mode: number, scale: number = this.scaleValue, animations: boolean = this.animations): Promise<void> {
    try { await Appearance.update(this.getUIContext().getHostContext() as common.UIAbilityContext,mode,scale,animations); this.mode = mode; this.scaleValue = scale; this.animations = animations; this.message = ''; }
    catch (e) { this.message = '设置保存失败：'+(e as Error).message; }
  }
  private pageScroller: Scroller = new Scroller();

  @Builder
  pageContent() {
      Scroll(this.pageScroller) {
        Column({space:20}) {
          Text('配色模式').width('100%').fontSize(22 * this.uiScale)
          Select([{value:'跟随系统'},{value:'浅色'},{value:'深色'}]).width('100%')
            .selected(this.mode === -1 ? 0 : this.mode === 1 ? 1 : 2).value(this.mode === -1 ? '跟随系统' : this.mode === 1 ? '浅色' : '深色')
            .onSelect((i: number) => this.change(i === 0 ? -1 : i === 1 ? 1 : 0))
          Text('界面大小：' + Math.round(this.scaleValue*100) + '%').width('100%')
          Slider({value:this.scaleValue,min:1,max:1.2,step:0.05}).width('100%').onChange((v: number,mode: SliderChangeMode) => { if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) { this.change(this.mode,v); } })
          Text('在系统字号基础上调整文字与控件大小。').width('100%')
          Row() { Text('页面切换动画').layoutWeight(1); Toggle({type:ToggleType.Switch,isOn:this.animations}).onChange((v: boolean) => this.change(this.mode,this.scaleValue,v)) }.width('100%')
          Button('恢复默认设置').type(ButtonType.Normal).buttonStyle(ButtonStyleMode.NORMAL).borderRadius(16).width('100%').height(48 * this.uiScale).onClick(() => this.change(-1,1,true))
          if (this.message) { Text(this.message).width('100%') }
        }.padding(24).width('100%')
      }.clip(!supportsImmersiveNavigation()).width('100%').height('100%').align(Alignment.TopStart)
  }

  build() {
    if (supportsImmersiveNavigation()) {
      HdsNavDestination() { this.pageContent() }
        .bindToScrollable([this.pageScroller])
        .titleBar(gradientTitleBar('外观设置')).systemBarStyle({ statusBarContentColor: this.statusBarContentColor },
          { statusBarContentColor: this.statusBarContentColor }).titleMode(HdsNavDestinationTitleMode.MINI).backgroundColor($r('app.color.page_background'))
    } else {
      NavDestination() { this.pageContent() }.title('外观设置').backgroundColor($r('app.color.page_background'))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
  }
}
