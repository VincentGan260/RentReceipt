import { util } from '@kit.ArkTS';
import { Room, PricingSettings, BillDraft, CustomCharge, MERGED_RENT_CHARGE_PREFIX } from '../model/Models';
import { calculateBill, withMergedRent } from '../model/BillCalculator';
import { cloneDraft, optionalNumber } from '../model/UiLogic';
import { StoreSession } from '../data/StoreSession';
import { FormField, ChargeEditor } from './FormComponents';

@Component
export struct EntryCard {
  @StorageLink('pageScale') uiScale: number = 1;
  @Prop room: Room = new Room();
  @Prop settings: PricingSettings = new PricingSettings();
  month: string = '';
  onSaved: () => void = () => {};
  @State draft: BillDraft = new BillDraft();
  @State message: string = '';
  @State correctionExpanded: boolean = false;
  @State chargesExpanded: boolean = false;
  private active: boolean = false;

  aboutToAppear(): void {
    this.active = true;
    const state = StoreSession.entries!.state(this.room, this.month);
    this.draft = cloneDraft(state.draft); this.message = state.message;
    this.correctionExpanded = this.draft.waterUsageOverride !== undefined || this.draft.electricityUsageOverride !== undefined;
  }

  aboutToDisappear(): void { this.active = false; }

  private total(): string {
    try { return '¥ ' + calculateBill(this.room, this.settings, this.draft).total; }
    catch { return '待填写完整'; }
  }

  private edit(field: number, value: string): void {
    const draft = cloneDraft(this.draft);
    switch (field) {
      case 0: draft.previousWater = value; break;
      case 1: draft.currentWater = value; break;
      case 2: draft.previousElectricity = value; break;
      case 3: draft.currentElectricity = value; break;
      case 4: draft.waterUsageOverride = optionalNumber(value); break;
      case 5: draft.electricityUsageOverride = optionalNumber(value); break;
    }
    this.draft = draft; this.persist();
  }

  private async persist(): Promise<void> {
    this.message = '正在保存…';
    try {
      await StoreSession.entries!.update(this.room, this.settings, this.draft, util.generateRandomUUID());
      this.onSaved();
    } catch { /* Workflow keeps input and a retryable failure message. */ }
    if (this.active) { this.message = StoreSession.entries!.state(this.room, this.month).message; }
  }

  build() {
    Column({ space: 16 }) {
      Row({ space: 12 }) {
        Text(this.room.number + ' 房').fontSize(20 * this.uiScale).fontWeight(FontWeight.Medium).layoutWeight(1)
        Text(this.total()).fontSize(20 * this.uiScale).fontWeight(FontWeight.Medium)
      }.width('100%')
      Text('月租 ¥ ' + this.room.rent).fontSize(14 * this.uiScale).fontColor($r('sys.color.ohos_id_color_text_secondary')).width('100%')
      Divider().opacity(0.12)
      Row({ space: 12 }) {
        if (!this.draft.rentOnly) {
          FormField({ label: '上期水表', text: this.draft.previousWater, onEdit: (value: string) => this.edit(0, value) }).layoutWeight(1)
        }
        FormField({ label: this.draft.rentOnly ? '入住水表读数' : '本期水表', text: this.draft.currentWater,
          onEdit: (value: string) => this.edit(1, value) }).layoutWeight(1)
      }.width('100%')
      Row({ space: 12 }) {
        if (!this.draft.rentOnly) {
          FormField({ label: '上期电表', text: this.draft.previousElectricity, onEdit: (value: string) => this.edit(2, value) }).layoutWeight(1)
        }
        FormField({ label: this.draft.rentOnly ? '入住电表读数' : '本期电表', text: this.draft.currentElectricity,
          onEdit: (value: string) => this.edit(3, value) }).layoutWeight(1)
      }.width('100%')
      if (!this.draft.rentOnly) {
        Button() {
          Row() {
            Text('换表或表数归零').fontSize(14 * this.uiScale).layoutWeight(1)
            SymbolGlyph(this.correctionExpanded ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down')).fontSize(12).fontColor([$r('sys.color.ohos_id_color_text_secondary')])
          }.width('100%')
        }.type(ButtonType.Normal).buttonStyle(ButtonStyleMode.TEXTUAL).width('100%').height(48 * this.uiScale)
          .accessibilityText('换表或表数归零').onClick(() => { this.correctionExpanded = !this.correctionExpanded; })
        if (this.correctionExpanded) {
          Text('表具归零按设置的上限折算；换表时填写实际用量。').fontSize(12 * this.uiScale)
            .fontColor($r('sys.color.ohos_id_color_text_secondary')).width('100%')
          Row({ space: 12 }) {
            FormField({ label: '水表换表实际用量', text: this.draft.waterUsageOverride ?? '', hint: '留空自动计算',
              onEdit: (value: string) => this.edit(4, value) }).layoutWeight(1)
            FormField({ label: '电表换表实际用量', text: this.draft.electricityUsageOverride ?? '', hint: '留空自动计算',
              onEdit: (value: string) => this.edit(5, value) }).layoutWeight(1)
          }.width('100%')
        }
      }
      if (this.draft.customCharges.some((charge: CustomCharge) => charge.name.startsWith(MERGED_RENT_CHARGE_PREFIX))) {
        Button('取消本期补收房租').type(ButtonType.Normal).buttonStyle(ButtonStyleMode.NORMAL).borderRadius(16).width('100%').height(48 * this.uiScale)
          .onClick(() => { this.draft = withMergedRent(this.draft, this.room.rent, []); this.persist(); })
      }
      Button() {
        Row() {
          Text('其他收费（' + this.draft.customCharges.length + '）').fontSize(14 * this.uiScale).layoutWeight(1)
          SymbolGlyph(this.chargesExpanded ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down')).fontSize(12).fontColor([$r('sys.color.ohos_id_color_text_secondary')])
        }.width('100%')
      }.type(ButtonType.Normal).buttonStyle(ButtonStyleMode.TEXTUAL).width('100%').height(48 * this.uiScale)
        .accessibilityText('其他收费').onClick(() => { this.chargesExpanded = !this.chargesExpanded; })
      if (this.chargesExpanded) {
        ChargeEditor({ charges: this.draft.customCharges, onEdit: (values: CustomCharge[]) => {
          this.draft.customCharges = values; this.persist();
        } })
      }
      Text(this.message).fontSize(14 * this.uiScale).width('100%')
        .fontColor(this.message.startsWith('未保存') ? $r('app.color.danger') : $r('sys.color.ohos_id_color_text_secondary'))
      if (this.message.startsWith('未保存')) {
        Button('保存 / 重试').type(ButtonType.Normal).buttonStyle(ButtonStyleMode.NORMAL).borderRadius(16).width('100%').height(48 * this.uiScale).onClick(() => { this.persist(); })
      }
    }.width('100%').alignItems(HorizontalAlign.Start).padding(18).borderRadius(20)
      .backgroundColor($r('app.color.surface'))
  }
}
