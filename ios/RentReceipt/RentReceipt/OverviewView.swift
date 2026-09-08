import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var store: AppStore
    @State private var search = ""
    @State private var month = MonthValue.current.next
    @State private var pendingPaidState: Bool?

    private var rooms: [Room] {
        store.rooms().filter { search.isEmpty || $0.number.localizedCaseInsensitiveContains(search) }
    }
    private var bills: [Bill] { store.bills(month: month.id) }
    private var total: Decimal {
        bills.reduce(Decimal.zero) { $0 + (Decimal(string: $1.total) ?? 0) }
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                LazyVStack(spacing: 14) {
                    AppCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Button { month = month.previous } label: { Image(systemName: "chevron.left") }
                                    .frame(minWidth: 44, minHeight: 44)
                                    .accessibilityLabel("上一个月")
                                Spacer()
                                VStack(spacing: 3) {
                                    Text(month.rentTitle).font(.title2.bold())
                                    Text("含 \(month.previous.utilityTitle) 水电费").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button { month = month.next } label: { Image(systemName: "chevron.right") }
                                    .frame(minWidth: 44, minHeight: 44)
                                    .accessibilityLabel("下一个月")
                            }
                        }
                    }

                    AdaptiveStack(spacing: 10) {
                        StatTile(title: "房间", value: "\(store.rooms().count)", icon: "door.left.hand.closed")
                        StatTile(title: "已出账", value: "\(bills.count)", icon: "doc.text.fill")
                        StatTile(title: "合计", value: "¥\(BillCalculator.text(total))", icon: "yensign.circle.fill")
                    }

                    if !bills.isEmpty {
                        Button {
                            pendingPaidState = bills.contains(where: { !$0.paid })
                        } label: {
                            Label(
                                bills.allSatisfy(\.paid) ? "将本月账单全部标记为未收" : "将本月账单全部标记为已收",
                                systemImage: bills.allSatisfy(\.paid) ? "arrow.uturn.backward.circle" : "checkmark.seal.fill"
                            )
                                .frame(maxWidth: .infinity)
                        }
                        .prominentGlassButton()
                    }

                    if rooms.isEmpty {
                        EmptyState(icon: "magnifyingglass", title: "没有找到房间", detail: search.isEmpty ? "请先在“房间”页面新增房间。" : "请检查房间号后重试。")
                    } else {
                        ForEach(rooms) { room in
                            NavigationLink {
                                RoomHistoryView(room: room)
                            } label: {
                                RoomOverviewCard(room: room, bill: bills.first { $0.roomId == room.id })
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 18)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .softTitleScrollEdge()
        }
        .navigationTitle("房租概览")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { BuildingMenu() } }
        .searchable(text: $search, prompt: "搜索房间号")
        .alert(pendingPaidState == true ? "确认整月收款？" : "将整月恢复为未收？", isPresented: Binding(
            get: { pendingPaidState != nil },
            set: { if !$0 { pendingPaidState = nil } }
        )) {
            Button("取消", role: .cancel) { pendingPaidState = nil }
            Button(pendingPaidState == true ? "确认已收" : "确认未收") {
                if let paid = pendingPaidState { store.setMonthPaid(month: month.id, paid: paid) }
                pendingPaidState = nil
            }
        } message: {
            Text("这会修改 \(bills.count) 张账单的收款状态，之后仍可再次更改。")
        }
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let icon: String
    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 7) {
                Image(systemName: icon).foregroundStyle(AppPalette.blue)
                Text(value).font(.headline).minimumScaleFactor(0.7).lineLimit(1)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct RoomOverviewCard: View {
    let room: Room
    let bill: Bill?
    var body: some View {
        AppCard {
            HStack(spacing: 14) {
                Image(systemName: room.occupied ? "person.crop.circle.fill" : "door.left.hand.closed")
                    .font(.title2).foregroundStyle(room.occupied ? AppPalette.blue : .secondary)
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(room.number) 房").font(.headline)
                    Text(room.occupied ? "已出租" : "空置").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let bill {
                    VStack(alignment: .trailing, spacing: 4) {
                        CurrencyText(value: bill.total).font(.headline)
                        Label(bill.paid ? "已收" : "未收", systemImage: bill.paid ? "checkmark.circle.fill" : "clock")
                            .font(.caption).foregroundStyle(bill.paid ? .green : .orange)
                    }
                } else { Text("未生成账单").font(.caption).foregroundStyle(.secondary) }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary).accessibilityHidden(true)
            }
        }
    }
}

struct RoomHistoryView: View {
    @EnvironmentObject private var store: AppStore
    let room: Room
    private var bills: [Bill] { store.data.bills.filter { $0.roomId == room.id }.sorted { $0.month > $1.month } }
    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                LazyVStack(spacing: 14) {
                    AppCard {
                        Text("\(room.number) 房").font(.largeTitle.bold())
                        Text("月租 ¥\(room.rent) · 押金 ¥\(room.depositAmount)（\(room.depositStatus.title)）")
                            .foregroundStyle(.secondary)
                    }
                    if bills.isEmpty { EmptyState(icon: "doc", title: "暂无历史账单", detail: "完成数据录入后，账单会显示在这里。") }
                    ForEach(bills) { bill in
                        NavigationLink { ReceiptPreviewView(bill: bill) } label: {
                            AppCard {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(bill.month).font(.headline)
                                        Text("水 \(bill.waterUsage) · 电 \(bill.electricityUsage)").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    CurrencyText(value: bill.total).font(.title3.bold())
                                    Image(systemName: "chevron.right").foregroundStyle(.tertiary).accessibilityHidden(true)
                                }
                            }
                        }.buttonStyle(.plain)
                    }
                }.padding(16).frame(maxWidth: 900).frame(maxWidth: .infinity)
            }
            .softTitleScrollEdge()
        }
        .navigationTitle("历史账单")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MonthValue: Hashable {
    var year: Int
    var month: Int
    static var current: Self {
        let parts = Calendar.current.dateComponents([.year, .month], from: Date())
        return .init(year: parts.year!, month: parts.month!)
    }
    var id: String { String(format: "%04d-%02d", year, month) }
    var rentTitle: String { "\(year) 年 \(month) 月房租" }
    var utilityTitle: String { "\(year) 年 \(month) 月" }
    var previous: Self { adding(-1) }
    var next: Self { adding(1) }
    static func parse(_ value: String) -> Self? {
        let pieces = value.split(separator: "-")
        guard pieces.count == 2, let year = Int(pieces[0]), let month = Int(pieces[1]), (1...12).contains(month) else { return nil }
        return .init(year: year, month: month)
    }
    static func missingBillMonths(previous: String?, target: Self) -> [Self] {
        guard let previous, var cursor = parse(previous)?.next, cursor != target else { return [] }
        var result: [Self] = []
        while cursor.id < target.id {
            result.append(cursor)
            cursor = cursor.next
        }
        return result
    }
    private func adding(_ amount: Int) -> Self {
        let date = Calendar.current.date(from: DateComponents(year: year, month: month))!
        let result = Calendar.current.date(byAdding: .month, value: amount, to: date)!
        let parts = Calendar.current.dateComponents([.year, .month], from: result)
        return .init(year: parts.year!, month: parts.month!)
    }
}
