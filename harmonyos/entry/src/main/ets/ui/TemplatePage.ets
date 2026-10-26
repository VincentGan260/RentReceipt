import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { supportsImmersiveNavigation, gradientTitleBar } from './ImmersiveNavigation';
import { Building, ReceiptTemplate, ReceiptTextElement } from '../model/Models';
import { StoreSession } from '../data/StoreSession';
import { FormField } from './FormComponents';

@Component
export struct TemplatePage {
  @StorageLink('statusBarContentColor') statusBarContentColor: string = '#000000';
  @StorageLink('pageScale') uiScale: number = 1;
  buildingId: string = '';
  onSaved: () => void = () => {};
  @State template: ReceiptTemplate = new ReceiptTemplate();
  @State index: number = 0;
  @State content: string = '';
  @State x: string = '';
  @State y: string = '';
  @State fontSizeText: string = '';
  @State centered: boolean = false;
  @State color: string = 'body';
  @State busy: boolean = false;
  @State message: string = '';
  aboutToAppear(): void {
    const data = StoreSession.store!.snapshot().data;
    this.template = data.buildings.find((b: Building) => b.id === this.buildingId)?.receiptTemplate ?? data.receiptTemplate;
    this.load(0);
  }
  private load(index: number): void {
    this.index = index; const e = this.template.elements[index];
    if (!e) { return; }
    this.content = e.content; this.x = String(e.x); this.y = String(e.y); this.fontSizeText = String(e.fontSize); this.centered = e.centered; this.color = e.color;
  }
  private apply(): boolean {
    const x = Number(this.x), y = Number(this.y), size = Number(this.fontSizeText);
    if (!this.x.trim() || !this.y.trim() || !this.fontSizeText.trim() || ![x,y,size].every((n: number) => Number.isFinite(n)) || size <= 0 || size > 500) {
      this.message = '请填写有效坐标和 1–500 的字号'; return false;
    }
    const copy = JSON.parse(JSON.stringify(this.template)) as ReceiptTemplate;
    const e = copy.elements[this.index]; e.content = this.content; e.x = x; e.y = y; e.fontSize = size; e.centered = this.centered; e.color = this.color;
    this.template = copy; this.message = ''; return true;
  }
  private async save(reset: boolean = false): Promise<void> {
    if (!reset && !this.apply()) { return; }
    this.busy = true;
    try {
      await StoreSession.store!.saveTemplate(this.buildingId,reset ? undefined : this.template);
      if (reset) { this.aboutToAppear(); }
      this.message = reset ? '已恢复默认模板' : '当前楼栋模板已保存'; this.onSaved();
    } catch (e) { this.message = (e as Error).message; }
    finally { this.busy = false; }
  }
  private pageScroller: Scroller = new Scroller();

  @Builder
  pageContent() {
      Scroll(this.pageScroller) {
        Column({space:16}) {
          Text('编辑当前楼栋的收据模板。占位符会在出图时替换为账单数据；表格单元格内的文字自动居中，字号会按单元格宽度适配。').width('100%')
          Select(this.template.elements.map((e: ReceiptTextElement): SelectOption => { return {value:e.id}; }))
            .selected(this.index).value(this.template.elements[this.index]?.id ?? '').width('100%')
            .onSelect((i: number) => { if (this.apply()) { this.load(i); } })
          FormField({label:'文字或占位符',text:this.content,decimal:false,onEdit:(v: string) => { this.content = v; }})
          FormField({label:'横坐标',text:this.x,onEdit:(v: string) => { this.x = v; }})
          FormField({label:'纵坐标',text:this.y,onEdit:(v: string) => { this.y = v; }})
          FormField({label:'字号',text:this.fontSizeText,onEdit:(v: string) => { this.fontSizeText = v; }})
          Row() { Text('居中').layoutWeight(1); Toggle({type:ToggleType.Switch,isOn:this.centered}).onChange((v: boolean) => { this.centered = v; }) }.width('100%')
          Select([{value:'正文'},{value:'蓝色'},{value:'红色'}]).value(this.color === 'blue' ? '蓝色' : this.color === 'red' ? '红色' : '正文')
            .selected(['body','blue','red'].indexOf(this.color)).onSelect((i: number) => { this.color = ['body','blue','red'][i]; })
          Button('保存楼栋模板').width('100%').height(48 * this.uiScale).enabled(!this.busy).onClick(() => this.save())
          Button('恢复默认模板').type(ButtonType.Normal).buttonStyle(ButtonStyleMode.NORMAL).borderRadius(16).width('100%').height(48 * this.uiScale).enabled(!this.busy).onClick(() => {
            this.getUIContext().showAlertDialog({title:'恢复默认模板？',message:'当前楼栋将改用默认收据模板。',primaryButton:{value:'取消',action:() => {}},secondaryButton:{value:'恢复默认',action:() => { this.save(true); }}});
          })
          if (this.message) { Text(this.message).width('100%') }
        }.padding(20).width('100%')
      }.clip(!supportsImmersiveNavigation()).width('100%').height('100%').align(Alignment.TopStart)
  }

  build() {
    if (supportsImmersiveNavigation()) {
      HdsNavDestination() { this.pageContent() }
        .bindToScrollable([this.pageScroller])
        .titleBar(gradientTitleBar('收据模板')).systemBarStyle({ statusBarContentColor: this.statusBarContentColor },
          { statusBarContentColor: this.statusBarContentColor }).titleMode(HdsNavDestinationTitleMode.MINI).onBackPressed(() => this.busy).backgroundColor($r('app.color.page_background'))
    } else {
      NavDestination() { this.pageContent() }.onBackPressed(() => this.busy).title('收据模板').backgroundColor($r('app.color.page_background'))
    }
  }
}
