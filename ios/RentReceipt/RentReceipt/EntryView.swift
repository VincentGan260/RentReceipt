import SwiftUI

struct EntryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var readingMonth = MonthValue.current
    @State private var mergedRentMonths: [MonthValue] = []
    @State private var missingRentMonths: [MonthValue] = []
    @State private var showingMissingMonthAlert = false
    @State private var message: String?
    @State private var exportItems: [URL] = []
    @State private var showingShare = false
    @State private var exporting = false

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                LazyVStack(spacing: 14) {
                    AppCard {
                        VStack(spacing: 12) {
                            HStack {
                                Button { selectReadingMonth(readingMonth.previous) } label: { Image(systemName: "chevron.left") }
                                    .frame(minWidth: 44, minHeight: 44)
                                    .accessibilityLabel("上一个月")
                                Spacer()
                                VStack(spacing: 3) {
                                    Text("\(readingMonth.year) 年 \(readingMonth.month) 月抄表").font(.title2.bold())
                                    Text("生成 \(readingMonth.next.rentTitle)").font(.caption).foregroundStyle(.secondary)
                                    Text("收据日期：\(readingMonth.next.id)-01").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button { selectReadingMonth(readingMonth.next) } label: { Image(systemName: "chevron.right") }
                                    .frame(minWidth: 44, minHeight: 44)
                                    .accessibilityLabel("下一个月")
                            }
                        }
                    }

                    if let message {
                        Label(message, systemImage: "checkmark.circle.fill")
                            .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if store.rooms().isEmpty {
                        EmptyState(icon: "door.left.hand.open", title: "尚无房间", detail: "请先到“房间”页面新增房间。")
                    } else {
                        ForEach(store.rooms()) { room in
                            RoomEntryCard(
                                room: room,
                                readingMonth: readingMonth,
                                billMonth: readingMonth.next.id,
                                mergedRentMonths: mergedRentMonths
                            ) { result in
                                switch result {
                                case .success(let bill):
                                    store.upsert(bill)
                                    message = "已自动保存 \(room.number) 房"
                                case .failure(let error): message = error.localizedDescription
                                }
                            }
                            .id("\(room.id)-\(readingMonth.id)-\(store.selectedBuildingID)")
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 30)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .softTitleScrollEdge()
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("数据录入")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { BuildingMenu() }
            ToolbarItem(placement: .topBarTrailing) {
                if exporting {
                    ProgressView().accessibilityLabel("正在导出收据")
                } else {
                    Button { exportReceipts() } label: { Label("导出", systemImage: "square.and.arrow.up") }
                }
            }
        }
        .sheet(isPresented: $showingShare) { ShareSheet(items: exportItems) }
        .alert("检测到中间月份没有抄表", isPresented: $showingMissingMonthAlert) {
            Button("合并房租") { mergedRentMonths = missingRentMonths }
            Button("不合并") { mergedRentMonths = [] }
        } message: {
            Text("检测到 \(missingRentMonths.map { "\($0.year)年\($0.month)月" }.joined(separator: "、")) 没有单独账单。是否将这些月份房租合并到本次？水电将按上次与本次实际抄表读数计算。")
        }
        .onAppear { selectReadingMonth(readingMonth) }
        .onChange(of: store.selectedBuildingID) { _ in selectReadingMonth(readingMonth) }
    }

    private func selectReadingMonth(_ value: MonthValue) {
        readingMonth = value
        mergedRentMonths = []
        let targetBillMonth = value.next
        if store.bills(month: targetBillMonth.id).isEmpty {
            let previous = store.data.bills
                .filter { $0.buildingId == store.selectedBuildingID && $0.month < targetBillMonth.id }
                .max { $0.month < $1.month }?.month
            missingRentMonths = MonthValue.missingBillMonths(previous: previous, target: targetBillMonth)
            showingMissingMonthAlert = !missingRentMonths.isEmpty
        } else {
            missingRentMonths = []
            showingMissingMonthAlert = false
        }
    }

    private func exportReceipts() {
        let bills = store.bills(month: readingMonth.next.id)
        guard !bills.isEmpty else {
            message = "本月还没有可导出的账单"
            return
        }
        exporting = true
        Task {
            do {
                exportItems = try await Task.detached(priority: .userInitiated) {
                    try bills.map { try ReceiptRenderer.writeTemporaryPNG(for: $0) }
                }.value
                showingShare = true
            } catch {
                message = "导出失败：\(error.localizedDescription)"
            }
            exporting = false
        }
    }
}

private struct RoomEntryCard: View {
    @EnvironmentObject private var store: AppStore
    let room: Room
    let readingMonth: MonthValue
    let billMonth: String
    let mergedRentMonths: [MonthValue]
    let onResult: (Result<Bill, Error>) -> Void

    @State private var draft: BillDraft
    @State private var previewTotal: String?
    @State private var error: String?
    @State private var saveTask: Task<Void, Never>?

    init(room: Room, readingMonth: MonthValue, billMonth: String, mergedRentMonths: [MonthValue], onResult: @escaping (Result<Bill, Error>) -> Void) {
        self.room = room
        self.readingMonth = readingMonth
        self.billMonth = billMonth
        self.mergedRentMonths = mergedRentMonths
        self.onResult = onResult
        _draft = State(initialValue: .init(month: billMonth))
    }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 13) {
                AdaptiveStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(room.number) 房").font(.title3.bold())
                        Text("月租 ¥\(room.rent)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let previewTotal { Text("¥\(previewTotal)").font(.title3.bold()).foregroundStyle(AppPalette.blue) }
                }

                if !mergedRentMonths.isEmpty {
                    Text("本单同时补收 \(mergedRentMonths.map { "\($0.year)年\($0.month)月" }.joined(separator: "、")) 房租，水电按两次实际抄表读数计算。")
                        .font(.caption).foregroundStyle(AppPalette.blue)
                }
                AdaptiveStack {
                    NumberInput("\(previousReadingMonth.month)月水表", text: binding(\.previousWater))
                    NumberInput("\(readingMonth.month)月水表", text: binding(\.currentWater))
                }
                AdaptiveStack {
                    NumberInput("\(previousReadingMonth.month)月电表", text: binding(\.previousElectricity))
                    NumberInput("\(readingMonth.month)月电表", text: binding(\.currentElectricity))
                }
                    DisclosureGroup("换表或表数归零") {
                        AdaptiveStack { NumberInput("水表实际用量", text: optionalBinding(\.waterUsageOverride)); NumberInput("电表实际用量", text: optionalBinding(\.electricityUsageOverride)) }
                            .padding(.top, 8)
                    }.font(.subheadline)
                DisclosureGroup("其他收费（\(draft.customCharges.count)）") {
                    VStack(spacing: 8) {
                        ForEach(Array(draft.customCharges.enumerated()), id: \.element.id) { index, _ in
                            AdaptiveStack {
                                LabeledTextInput("项目名称", text: customChargeBinding(index, \.name))
                                LabeledTextInput("金额", text: customChargeBinding(index, \.amount), keyboard: .decimalPad)
                                Button(role: .destructive) { draft.customCharges.remove(at: index); changed() } label: { Image(systemName: "minus.circle.fill") }
                                    .frame(minWidth: 44, minHeight: 44)
                                    .accessibilityLabel("删除收费项")
                            }
                        }
                        Button { draft.customCharges.append(CustomCharge()); changed() } label: { Label("添加收费项", systemImage: "plus.circle") }
                    }.padding(.top, 8)
                }.font(.subheadline)
                if let error { Text(error).font(.caption).foregroundStyle(.orange) }
            }
        }
        .onAppear {
            if let saved = store.draft(roomID: room.id, month: billMonth) { draft = saved; draft.rentOnly = false }
            else if let existing = store.data.bills.first(where: { $0.roomId == room.id && $0.month == billMonth }) {
                draft = .init(month: billMonth, previousWater: existing.previousWater, currentWater: existing.currentWater,
                              previousElectricity: existing.previousElectricity, currentElectricity: existing.currentElectricity,
                              rentOnly: false, customCharges: existing.customCharges)
            } else if let previous = store.data.bills.filter({ $0.roomId == room.id && $0.month < billMonth }).max(by: { $0.month < $1.month }) {
                draft.previousWater = previous.currentWater
                draft.previousElectricity = previous.currentElectricity
            }
            recalculate()
        }
        .onChange(of: mergedRentMonths) { _ in changed() }
    }

    private func binding<T>(_ path: WritableKeyPath<BillDraft, T>) -> Binding<T> {
        Binding(get: { draft[keyPath: path] }, set: { value in
            draft[keyPath: path] = value
            changed()
        })
    }

    private func optionalBinding(_ path: WritableKeyPath<BillDraft, String?>) -> Binding<String> {
        Binding(get: { draft[keyPath: path] ?? "" }, set: { value in
            draft[keyPath: path] = value.isEmpty ? nil : value
            changed()
        })
    }

    private func customChargeBinding(_ index: Int, _ path: WritableKeyPath<CustomCharge, String>) -> Binding<String> {
        Binding(get: { draft.customCharges[index][keyPath: path] }, set: { value in
            draft.customCharges[index][keyPath: path] = value
            changed()
        })
    }

    private func changed() {
        draft.rentOnly = false
        let effectiveDraft = draft.withMergedRent(room.rent, months: mergedRentMonths)
        store.saveDraft(effectiveDraft, roomID: room.id)
        recalculate()
        saveTask?.cancel()
        let current = effectiveDraft
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            do { onResult(.success(try BillCalculator.makeBill(room: room, settings: store.selectedBuilding.settings, draft: current))) }
            catch { if complete(current) { onResult(.failure(error)) } }
        }
    }

    private func recalculate() {
        do {
            previewTotal = BillCalculator.text(try BillCalculator.calculate(room: room, settings: store.selectedBuilding.settings, draft: draft.withMergedRent(room.rent, months: mergedRentMonths)).total)
            error = nil
        } catch { previewTotal = nil; self.error = error.localizedDescription }
    }

    private func complete(_ value: BillDraft) -> Bool {
        return !value.previousWater.isEmpty && !value.currentWater.isEmpty && !value.previousElectricity.isEmpty && !value.currentElectricity.isEmpty
    }

    private var previousReadingMonth: MonthValue {
        store.data.bills
            .filter { $0.roomId == room.id && $0.month < billMonth }
            .max { $0.month < $1.month }
            .flatMap { MonthValue.parse($0.month)?.previous } ?? readingMonth.previous
    }
}

private struct NumberInput: View {
    let title: String
    @Binding var text: String
    init(_ title: String, text: Binding<String>) { self.title = title; _text = text }
    var body: some View {
        LabeledTextInput(title, text: $text, keyboard: .decimalPad)
    }
}

private struct LabeledTextInput: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    init(_ title: String, text: Binding<String>, keyboard: UIKeyboardType = .default) {
        self.title = title
        _text = text
        self.keyboard = keyboard
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(title, text: $text)
                .keyboardType(keyboard)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(title)
        }
    }
}
