import SwiftUI

struct RoomEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let original: Room?
    @State private var room: Room
    @State private var confirmDelete = false
    @State private var error: String?

    init(room: Room?) {
        original = room
        _room = State(initialValue: room ?? Room(number: "", rent: "", buildingId: defaultBuildingID))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("房间") {
                    LabeledContent("房号") {
                        TextField("必填", text: $room.number).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("月租（元）") {
                        TextField("必填", text: $room.rent).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    Toggle("已出租", isOn: $room.occupied)
                }
                Section("押金") {
                    LabeledContent("押金金额（元）") {
                        TextField("必填", text: $room.depositAmount).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    Picker("押金状态", selection: $room.depositStatus) {
                        ForEach(DepositStatus.allCases) { Text($0.title).tag($0) }
                    }
                }
                Section {
                    OptionalNumberField("自定义水价", value: $room.customWaterRate)
                    OptionalNumberField("自定义电价", value: $room.customElectricityRate)
                } header: { Text("房间独立单价") } footer: { Text("留空则使用当前楼栋的默认价格。") }
                Section {
                    OptionalNumberField("水表上限", value: $room.customWaterMeterMax)
                    OptionalNumberField("电表上限", value: $room.customElectricityMeterMax)
                } header: { Text("表数归零上限") } footer: { Text("用于表数从最大值归零时计算用量；留空使用楼栋设置。") }
                if let error { Section { Text(error).foregroundStyle(.red) } }
                if original != nil {
                    Section { Button("删除房间", role: .destructive) { confirmDelete = true } }
                }
            }
            .navigationTitle(original == nil ? "新增房间" : "编辑 \(original!.number) 房")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { ModalCancelButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { ModalConfirmButton(enabled: canSave) { save() } }
            }
            .alert("删除这个房间？", isPresented: $confirmDelete) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    if let original { store.deleteRoom(id: original.id) }
                    dismiss()
                }
            } message: { Text("历史账单仍会保留。") }
        }
    }

    private func save() {
        guard !room.number.trimmingCharacters(in: .whitespaces).isEmpty,
              Decimal(string: room.rent) != nil, Decimal(string: room.depositAmount) != nil else {
            error = "请填写有效的房号、月租和押金"; return
        }
        room.number = room.number.trimmingCharacters(in: .whitespaces)
        room.buildingId = original?.buildingId ?? store.selectedBuildingID
        let today = Date.isoDayFormatter.string(from: Date())
        if room.depositStatus == .collected && room.depositCollectedDate == nil { room.depositCollectedDate = today }
        if room.depositStatus == .refunded && room.depositRefundedDate == nil { room.depositRefundedDate = today }
        store.upsert(room)
        dismiss()
    }

    private var canSave: Bool {
        !room.number.trimmingCharacters(in: .whitespaces).isEmpty &&
        Decimal(string: room.rent) != nil && Decimal(string: room.depositAmount) != nil
    }
}

private struct OptionalNumberField: View {
    let title: String
    @Binding var value: String?
    init(_ title: String, value: Binding<String?>) { self.title = title; _value = value }
    var body: some View {
        LabeledContent(title) {
            TextField("使用默认值", text: Binding(get: { value ?? "" }, set: { value = $0.isEmpty ? nil : $0 }))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct PricingSettingsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var settings: PricingSettings
    @State private var error: String?
    init(settings: PricingSettings) { _settings = State(initialValue: settings) }
    var body: some View {
        NavigationStack {
            Form {
                Section("默认单价") {
                    LabeledContent("水价（元/吨）") {
                        TextField("必填", text: $settings.defaultWaterRate).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("电价（元/度）") {
                        TextField("必填", text: $settings.defaultElectricityRate).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                }
                Section("表数归零上限") {
                    OptionalNumberField("水表上限", value: $settings.defaultWaterMeterMax)
                    OptionalNumberField("电表上限", value: $settings.defaultElectricityMeterMax)
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("楼栋设置").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { ModalCancelButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { ModalConfirmButton(enabled: canSave) { save() } }
            }
        }
    }
    private func save() {
        guard Decimal(string: settings.defaultWaterRate) != nil, Decimal(string: settings.defaultElectricityRate) != nil else {
            error = "请填写有效的水电单价"; return
        }
        store.updateSettings(settings); dismiss()
    }
    private var canSave: Bool {
        Decimal(string: settings.defaultWaterRate) != nil && Decimal(string: settings.defaultElectricityRate) != nil
    }
}

struct BuildingEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let building: Building?
    @State private var name: String
    init(building: Building?) { self.building = building; _name = State(initialValue: building?.name ?? "") }
    var body: some View {
        NavigationStack {
            Form {
                LabeledContent("楼栋名称") {
                    TextField("必填", text: $name).multilineTextAlignment(.trailing)
                }
            }
                .navigationTitle(building == nil ? "新增楼栋" : "修改楼栋名称")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { ModalCancelButton { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        ModalConfirmButton(enabled: !name.trimmingCharacters(in: .whitespaces).isEmpty) {
                            var value = building ?? Building(name: name.trimmingCharacters(in: .whitespaces))
                            value.name = name.trimmingCharacters(in: .whitespaces)
                            store.upsert(value); dismiss()
                        }
                    }
                }
        }
    }
}
