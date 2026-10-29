import { CustomCharge } from '../model/Models';

@Component
export struct FormField {
  @StorageLink('pageScale') uiScale: number = 1;
  label: string = '';
  @Prop text: string = '';
  hint: string = '';
  decimal: boolean = true;
  onEdit: (value: string) => void = () => {};
  inputId: string = '';
  readingNext: boolean = false;
  onContinue: () => void = () => {};

  build() {
    Column({ space: 8 }) {
      Text(this.label).fontSize(14 * this.uiScale).fontColor($r('sys.color.ohos_id_color_text_secondary')).width('100%')
      TextInput({ text: this.text, placeholder: this.hint })
        .type(this.decimal ? InputType.NUMBER_DECIMAL : InputType.Normal)
        .fontSize(16 * this.uiScale).height(48 * this.uiScale).onChange(this.onEdit)
        .accessibilityText(this.label)
        .id(this.inputId || undefined)
        .enterKeyType(this.readingNext ? EnterKeyType.Next : EnterKeyType.Done)
        .onSubmit((key: EnterKeyType, event: SubmitEvent) => {
          if (this.readingNext) { event.keepEditableState(); this.onContinue(); }
        })
    }.alignItems(HorizontalAlign.Start).width('100%')
  }
}

@Component
export struct ChargeEditor {
  @StorageLink('pageScale') uiScale: number = 1;
  @Prop charges: CustomCharge[] = [];
  title: string = '其他收费项';
  onEdit: (values: CustomCharge[]) => void = () => {};

  private change(index: number, text: string, isAmount: boolean): void {
    const values = JSON.parse(JSON.stringify(this.charges)) as CustomCharge[];
    if (isAmount) { values[index].amount = text; } else { values[index].name = text; }
    this.onEdit(values);
  }

  build() {
    Column({ space: 12 }) {
      Text(this.title).fontSize(20 * this.uiScale).fontWeight(FontWeight.Medium).width('100%')
      ForEach(this.charges.map((charge: CustomCharge, index: number) => index), (index: number) => {
        Column({ space: 8 }) {
          FormField({ label: '费用名称', text: this.charges[index]?.name ?? '', hint: '如：网络费', decimal: false,
            onEdit: (value: string) => this.change(index, value, false) })
          Row({ space: 12 }) {
            FormField({ label: '金额（元）', text: this.charges[index]?.amount ?? '', hint: '0',
              onEdit: (value: string) => this.change(index, value, true) }).layoutWeight(1)
            Button('移除').type(ButtonType.Normal).buttonStyle(ButtonStyleMode.NORMAL).borderRadius(16).height(48 * this.uiScale)
              .onClick(() => this.onEdit(this.charges.filter((value: CustomCharge, i: number) => i !== index)))
              .accessibilityText('移除第' + (index + 1) + '项费用')
          }
        }.width('100%')
      }, (index: number) => String(index))
      Button('添加收费项').type(ButtonType.Normal).buttonStyle(ButtonStyleMode.NORMAL).borderRadius(16).width('100%').height(48 * this.uiScale)
        .onClick(() => this.onEdit(this.charges.concat([new CustomCharge()])))
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}

@Component
export struct DetailLine {
  @StorageLink('pageScale') uiScale: number = 1;
  label: string = '';
  @Prop value: string = '';
  build() {
    Row({ space: 16 }) {
      Text(this.label).fontSize(16 * this.uiScale).fontColor($r('sys.color.ohos_id_color_text_secondary')).layoutWeight(1)
      Text(this.value).fontSize(16 * this.uiScale).textAlign(TextAlign.End).layoutWeight(1)
    }.width('100%')
  }
}
