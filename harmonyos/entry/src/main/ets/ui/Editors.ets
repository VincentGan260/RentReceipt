import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { supportsImmersiveNavigation, gradientTitleBar } from './ImmersiveNavigation';
import { util } from '@kit.ArkTS';
import { Building, Room, PricingSettings, DepositStatus, CustomCharge, AppData } from '../model/Models';
import { cloneRoom, validatePricing, validateRoom, optionalNumber, changeDepositStatus, today } from '../model/UiLogic';
import { StoreSession } from '../data/StoreSession';
import { FormField, ChargeEditor } from './FormComponents';

@Component
export struct BuildingEditor {
  @StorageLink('statusBarContentColor') statusBarContentColor: string = '#000000';
  @StorageLink('pageScale') uiScale: number = 1;
  original?: Building;
  paths: NavPathStack = new NavPathStack();
  onSaved: (previous: AppData) => void = () => {};
  @State building: Building = new Building();
  @State busy: boolean = false;
  @State message: string = '';

  aboutToAppear(): void {
    if (this.original) { this.building = JSON.parse(JSON.stringify(this.original)) as Building; }
    else { this.building.id = util.generateRandomUUID(); }
  }

  private editPrice(field: number, text: string): void {
    const value = JSON.parse(JSON.stringify(this.building.settings)) as PricingSettings;
    switch (field) {
      case 0: value.defaultWaterRate = text; break;
      case 1: value.defaultElectricityRate = text; break;
      case 2: value.defaultManagementRate = optionalNumber(text); break;
      case 3: value.defaultWaterMeterMax = optionalNumber(text); break;
      case 4: value.defaultElectricityMeterMax = optionalNumber(text); break;
    }
    this.building.settings = value;
  }

  private async save(): Promise<void> {
    if (this.busy) { return; }
    this.busy = true;
    try {
      if (!this.building.name.trim()) { throw new Error('请填写楼栋名称'); }
      validatePricing(this.building.settings);
      this.building.name = this.building.name.trim();
      const previous = (await StoreSession.store!.settledSnapshot()).data;
      await StoreSession.store!.saveBuilding(this.building);
      this.paths.pop(); this.onSaved(previous);
    } catch (error) { this.message = (error as Error).message; }
    finally { this.busy = false; }
  }

  private confirmDelete(): void {
    const id = this.building.id;
    const state = StoreSession.store!.snapshot();
    const rooms = state.data.rooms.filter((r: Room) => r.buildingId === id).length;
    const bills = state.data.bills.filter((b) => b.buildingId === id).length;
    this.getUIContext().showAlertDialog({
      title: '删除楼栋？', message: '将删除“' + this.building.name + '”及其 ' + rooms + ' 个房间、' + bills + ' 张账单和录入草稿。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '继续', action: () => {
        setTimeout(() => this.getUIContext().showAlertDialog({
          title: '确认永久删除', message: '删除后无法撤销。是否删除“' + this.building.name + '”的全部数据？',
          primaryButton: { value: '保留', action: () => {} },
          secondaryButton: { value: '永久删除', fontColor: $r('app.color.danger'), action: () => { this.remove(id); } }
        }), 100);
      } }
    });
  }

  private async remove(id: string): Promise<void> {
    if (this.busy) { return; }
    this.busy = true;
    const previous = StoreSession.store!.snapshot().data;
    try { await StoreSession.store!.deleteBuilding(id); this.paths.pop(); this.onSaved(previous); }
    catch (error) { this.message = (error as Error).message; }
    finally { this.busy = false; }
  }

  private pageScroller: Scroller = new Scroller();

  @Builder
  pageContent() {
      Scroll(this.pageScroller) {
        Column({ space: 20 }) {
          Column({ space: 16 }) {
            FormField({ label: '楼栋名称', text: this.building.name, decimal: false, hint: '如：南楼',
              onEdit: (value: string) => { this.building.name = value; } })
            Text('默认单价').fontSize(20 * this.uiScale).fontWeight(FontWeight.Medium).width('100%')
            FormField({ label: '水价（元/吨）', text: this.building.settings.defaultWaterRate,
              onEdit: (value: string) => this.editPrice(0, value) })
            FormField({ label: '电价（元/度）', text: this.building.settings.defaultElectricityRate,
              onEdit: (value: string) => this.editPrice(1, value) })
            FormField({ label: '公共服务费（元/度，可选）', text: this.building.settings.defaultManagementRate ?? '', hint: '留空不收取',
              onEdit: (value: string) => this.editPrice(2, value) })
            Text('公共服务费按本期用电量计算，四舍五入到元。').fontSize(14 * this.uiScale)
              .fontColor($r('sys.color.ohos_id_color_text_secondary')).width('100%')
            Text('表具归零上限').fontSize(20 * this.uiScale).fontWeight(FontWeight.Medium).width('100%')
            FormField({ label: '水表上限（可选）', text: this.building.settings.defaultWaterMeterMax ?? '', hint: '留空不折算',
              onEdit: (value: string) => this.editPrice(3, value) })
            FormField({ label: '电表上限（可选）', text: this.building.settings.defaultElectricityMeterMax ?? '', hint: '如：10000',
              onEdit: (value: string) => this.editPrice(4, value) })
          }.padding(20).borderRadius(24).backgroundColor($r('app.color.surface')).enabled(!this.busy)
          if (this.message) { Text(this.message).fontSize(16 * this.uiScale).fontColor($r('app.color.danger')).width('100%') }
          Row({ space: 12 }) {
            if (this.original) {
              Button('删除楼栋').type(ButtonType.Normal).buttonStyle(ButtonStyleMode.NORMAL).borderRadius(16)
                .layoutWeight(1).height(48 * this.uiScale).fontColor($r('app.color.danger'))
                .enabled(!this.busy).onClick(() => this.confirmDelete())
            }
            Button(this.busy ? '正在保存…' : '保存楼栋').type(ButtonType.Normal).borderRadius(16)
              .layoutWeight(1).height(48 * this.uiScale).enabled(!this.busy).onClick(() => { this.save(); })
          }.width('100%')
        }.width('100%').constraintSize({ maxWidth: 720 }).padding(16)
      }.expandSafeArea(supportsImmersiveNavigation() ? [] : [SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
        .clip(!supportsImmersiveNavigation()).width('100%').height('100%').align(Alignment.TopStart)
  }

  build() {
    if (supportsImmersiveNavigation()) {
      HdsNavDestination() { this.pageContent() }
        .bindToScrollable([this.pageScroller])
        .titleBar(gradientTitleBar(this.original ? '楼栋设置' : '新增楼栋')).systemBarStyle({ statusBarContentColor: this.statusBarContentColor },
          { statusBarContentColor: this.statusBarContentColor }).titleMode(HdsNavDestinationTitleMode.MINI).onBackPressed(() => this.busy)
      .backgroundColor($r('app.color.page_background'))
    } else {
      NavDestination() { this.pageContent() }.title(this.original ? '楼栋设置' : '新增楼栋').onBackPressed(() => this.busy)
      .backgroundColor($r('app.color.page_background'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
  }
}

@Component
export struct RoomEditor {
  @StorageLink('statusBarContentColor') statusBarContentColor: string = '#000000';
  @StorageLink('pageScale') uiScale: number = 1;
  original?: Room;
  buildingId: string = '';
  paths: NavPathStack = new NavPathStack();
  onSaved: (previous: AppData) => void = () => {};
  @State room: Room = new Room();
  @State busy: boolean = false;
  @State message: string = '';

  aboutToAppear(): void {
    if (this.original) { this.room = cloneRoom(this.original); }
    else { this.room.id = util.generateRandomUUID(); this.room.buildingId = this.buildingId; }
  }

  private editOverride(field: number, text: string): void {
    const room = cloneRoom(this.room);
    const value = optionalNumber(text);
    switch (field) {
      case 0: room.customWaterRate = value; break;
      case 1: room.customElectricityRate = value; break;
      case 2: room.customManagementRate = value; break;
      case 3: room.customWaterMeterMax = value; break;
      case 4: room.customElectricityMeterMax = value; break;
    }
    this.room = room;
  }

  private async save(): Promise<void> {
    if (this.busy) { return; }
    this.busy = true;
    try {
      validateRoom(this.room);
      const value = cloneRoom(this.room);
      value.number = value.number.trim();
      value.recurringCharges.forEach((charge: CustomCharge) => { charge.name = charge.name.trim(); });
      const previous = (await StoreSession.store!.settledSnapshot()).data;
      await StoreSession.store!.saveRoom(value);
      this.paths.pop(); this.onSaved(previous);
    } catch (error) { this.message = (error as Error).message; }
    finally { this.busy = false; }
  }

  private confirmDelete(): void {
    const id = this.room.id;
    this.getUIContext().showAlertDialog({
      title: '删除房间？', message: '删除 ' + this.room.number + ' 房及其草稿。已有历史账单继续保留。',
      primaryButton: { value: '保留', action: () => {} },
      secondaryButton: { value: '删除房间', fontColor: $r('app.color.danger'), action: () => { this.remove(id); } }
    });
  }

  private async remove(id: string): Promise<void> {
    this.busy = true;
    const previous = StoreSession.store!.snapshot().data;
    try { await StoreSession.store!.deleteRoom(id); this.paths.pop(); this.onSaved(previous); }
    catch (error) { this.message = (error as Error).message; }
    finally { this.busy = false; }
  }

  private pageScroller: Scroller = new Scroller();

  @Builder
  pageContent() {
      Scroll(this.pageScroller) {
        Column({ space: 20 }) {
          Column({ space: 16 }) {
            FormField({ label: '房号', text: this.room.number, decimal: false, hint: '如：101 或 铺1',
              onEdit: (value: string) => { this.room.number = value; } })
            FormField({ label: '月租（元）', text: this.room.rent, hint: '必填',
              onEdit: (value: string) => { this.room.rent = value; } })
            Row() {
              Text('已出租').fontSize(16 * this.uiScale).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.room.occupied })
                .onChange((value: boolean) => { this.room.occupied = value; }).accessibilityText('已出租')
            }.width('100%')
            Text('押金').fontSize(20 * this.uiScale).fontWeight(FontWeight.Medium).width('100%')
            FormField({ label: '押金金额（元）', text: this.room.depositAmount,
              onEdit: (value: string) => { this.room.depositAmount = value; } })
            Select([{ value: '未收押金' }, { value: '已收押金' }, { value: '已退押金' }])
              .value(this.room.depositStatus === DepositStatus.COLLECTED ? '已收押金' : this.room.depositStatus === DepositStatus.REFUNDED ? '已退押金' : '未收押金').selected([DepositStatus.NOT_COLLECTED, DepositStatus.COLLECTED, DepositStatus.REFUNDED].indexOf(this.room.depositStatus))
              .onSelect((index: number) => {
                this.room = changeDepositStatus(this.room,
                  [DepositStatus.NOT_COLLECTED, DepositStatus.COLLECTED, DepositStatus.REFUNDED][index], today());
              }).accessibilityText('押金状态')
            if (this.room.depositCollectedDate) { Text('收取日期：' + this.room.depositCollectedDate).fontSize(14 * this.uiScale).width('100%') }
            if (this.room.depositRefundedDate) { Text('退还日期：' + this.room.depositRefundedDate).fontSize(14 * this.uiScale).width('100%') }
          }.padding(20).borderRadius(24).backgroundColor($r('app.color.surface')).enabled(!this.busy)
          Column({ space: 16 }) {
            Text('房间独立设置').fontSize(20 * this.uiScale).fontWeight(FontWeight.Medium).width('100%')
            Text('留空跟随楼栋默认值；公共服务费填 0 可单独关闭。').fontSize(14 * this.uiScale)
              .fontColor($r('sys.color.ohos_id_color_text_secondary')).width('100%')
            FormField({ label: '独立水价（元/吨）', text: this.room.customWaterRate ?? '', hint: '跟随楼栋',
              onEdit: (value: string) => this.editOverride(0, value) })
            FormField({ label: '独立电价（元/度）', text: this.room.customElectricityRate ?? '', hint: '跟随楼栋',
              onEdit: (value: string) => this.editOverride(1, value) })
            FormField({ label: '独立公共服务费（元/度）', text: this.room.customManagementRate ?? '', hint: '跟随楼栋',
              onEdit: (value: string) => this.editOverride(2, value) })
            FormField({ label: '独立水表上限', text: this.room.customWaterMeterMax ?? '', hint: '跟随楼栋',
              onEdit: (value: string) => this.editOverride(3, value) })
            FormField({ label: '独立电表上限', text: this.room.customElectricityMeterMax ?? '', hint: '跟随楼栋',
              onEdit: (value: string) => this.editOverride(4, value) })
          }.padding(20).borderRadius(24).backgroundColor($r('app.color.surface')).enabled(!this.busy)
          ChargeEditor({ title: '每月固定费用', charges: this.room.recurringCharges,
            onEdit: (charges: CustomCharge[]) => { this.room.recurringCharges = charges; } })
            .padding(20).borderRadius(24).backgroundColor($r('app.color.surface')).enabled(!this.busy)
          if (this.message) { Text(this.message).fontSize(16 * this.uiScale).fontColor($r('app.color.danger')).width('100%') }
          Row({ space: 12 }) {
            if (this.original) {
              Button('删除房间').type(ButtonType.Normal).buttonStyle(ButtonStyleMode.NORMAL).borderRadius(16)
                .layoutWeight(1).height(48 * this.uiScale).fontColor($r('app.color.danger'))
                .enabled(!this.busy).onClick(() => this.confirmDelete())
            }
            Button(this.busy ? '正在保存…' : '保存房间').type(ButtonType.Normal).borderRadius(16)
              .layoutWeight(1).height(48 * this.uiScale).enabled(!this.busy).onClick(() => { this.save(); })
          }.width('100%')
        }.width('100%').constraintSize({ maxWidth: 720 }).padding(16)
      }.expandSafeArea(supportsImmersiveNavigation() ? [] : [SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
        .clip(!supportsImmersiveNavigation()).width('100%').height('100%').align(Alignment.TopStart)
  }

  build() {
    if (supportsImmersiveNavigation()) {
      HdsNavDestination() { this.pageContent() }
        .bindToScrollable([this.pageScroller])
        .titleBar(gradientTitleBar(this.original ? '编辑房间' : '新增房间')).systemBarStyle({ statusBarContentColor: this.statusBarContentColor },
          { statusBarContentColor: this.statusBarContentColor }).titleMode(HdsNavDestinationTitleMode.MINI).onBackPressed(() => this.busy)
      .backgroundColor($r('app.color.page_background'))
    } else {
      NavDestination() { this.pageContent() }.title(this.original ? '编辑房间' : '新增房间').onBackPressed(() => this.busy)
      .backgroundColor($r('app.color.page_background'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
  }
}
