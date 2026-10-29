import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var data: AppData
    @Published var selectedBuildingID: String
    @Published private(set) var lastPersistenceError: String?

    @Published var readingMonth = MonthValue.current
    @Published var pendingReexport: [Bill] = []
    @Published var repricingRevision = 0

    func prepareReexport(previous: AppData) {
        do {
            pendingReexport = try previous.bills.filter { $0.month == readingMonth.next.id }.compactMap { bill in
                guard let oldRoom = previous.rooms.first(where: { $0.id == bill.roomId && $0.buildingId == bill.buildingId }),
                      let room = data.rooms.first(where: { $0.id == bill.roomId && $0.buildingId == bill.buildingId }),
                      let oldSettings = previous.buildings.first(where: { $0.id == bill.buildingId })?.settings,
                      let settings = data.buildings.first(where: { $0.id == bill.buildingId })?.settings,
                      oldRoom.billingFees(oldSettings) != room.billingFees(settings) else { return nil }
                return try bill.repriced(room: room, settings: settings, previousRoom: oldRoom)
            }
        } catch { lastPersistenceError = "费用已保存，但准备重新导出失败：\(error.localizedDescription)" }
    }

    func saveRepricedBills(_ bills: [Bill]) {
        for bill in bills {
            let key = "\(bill.buildingId)|\(bill.roomId)|\(bill.month)"
            if var draft = drafts[key] {
                draft.customCharges = bill.customCharges
                drafts[key] = draft
            }
            upsert(bill)
        }
        let draftsSaved = saveDrafts()
        let draftError = draftsSaved ? nil : lastPersistenceError
        flush()
        if let draftError { lastPersistenceError = draftError }
        repricingRevision += 1
    }

    private let fileURL: URL
    private var drafts: [String: BillDraft] = [:]
    private var pendingSave: Task<Void, Never>?

    init(fileURL: URL? = nil) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.fileURL = fileURL ?? base.appendingPathComponent("RentReceipt/app-data.json")
        let loaded = Self.load(from: self.fileURL)
        data = loaded
        selectedBuildingID = loaded.buildings.first?.id ?? defaultBuildingID
        loadDrafts()
    }

    var selectedBuilding: Building {
        data.buildings.first(where: { $0.id == selectedBuildingID }) ?? data.buildings[0]
    }

    func rooms(in buildingID: String? = nil) -> [Room] {
        data.rooms.filter { $0.buildingId == (buildingID ?? selectedBuildingID) }.sorted(by: Room.ordered)
    }

    func bills(in buildingID: String? = nil, month: String? = nil) -> [Bill] {
        data.bills.filter {
            $0.buildingId == (buildingID ?? selectedBuildingID) && (month == nil || $0.month == month)
        }.sorted { lhs, rhs in lhs.roomNumber.localizedStandardCompare(rhs.roomNumber) == .orderedAscending }
    }

    func upsert(_ building: Building) {
        if let index = data.buildings.firstIndex(where: { $0.id == building.id }) { data.buildings[index] = building }
        else { data.buildings.append(building) }
        selectedBuildingID = building.id
        persist()
    }

    func upsert(_ room: Room) {
        if let index = data.rooms.firstIndex(where: { $0.id == room.id }) { data.rooms[index] = room }
        else { data.rooms.append(room) }
        data.rooms.sort(by: Room.ordered)
        persist()
    }

    func deleteRoom(id: String) {
        data.rooms.removeAll { $0.id == id }
        drafts = drafts.filter { $0.key.components(separatedBy: "|").dropFirst().first != id }
        saveDrafts()
        persist()
    }

    func deleteBuilding(id: String) {
        let roomIDs = Set(data.rooms.filter { $0.buildingId == id }.map(\.id))
        data.buildings.removeAll { $0.id == id }
        data.rooms.removeAll { $0.buildingId == id }
        data.bills.removeAll { $0.buildingId == id || roomIDs.contains($0.roomId) }
        drafts = drafts.filter { !$0.key.hasPrefix("\(id)|") }
        saveDrafts()
        selectedBuildingID = data.buildings.first?.id ?? ""
        persist()
    }

    func upsert(_ bill: Bill) {
        if let index = data.bills.firstIndex(where: { $0.roomId == bill.roomId && $0.month == bill.month }) {
            var value = bill
            value.id = data.bills[index].id
            value.paid = data.bills[index].paid
            value.paidDate = data.bills[index].paidDate
            data.bills[index] = value
        } else { data.bills.append(bill) }
        data.bills.sort { $0.month > $1.month }
        persist()
    }

    func setMonthPaid(month: String, paid: Bool) {
        let day = Date.isoDayFormatter.string(from: Date())
        for index in data.bills.indices where data.bills[index].buildingId == selectedBuildingID && data.bills[index].month == month && data.bills[index].paid != paid {
            data.bills[index].paid = paid
            data.bills[index].paidDate = paid ? day : nil
        }
        persist()
    }

    func dismissPersistenceError() { lastPersistenceError = nil }

    func updateSettings(_ settings: PricingSettings) {
        guard let index = data.buildings.firstIndex(where: { $0.id == selectedBuildingID }) else { return }
        data.buildings[index].settings = settings
        persist()
    }

    func entryDraft(room: Room, month: String) -> BillDraft {
        if var saved = draft(roomID: room.id, month: month) { saved.rentOnly = false; return saved }
        if let bill = data.bills.first(where: { $0.buildingId == room.buildingId && $0.roomId == room.id && $0.month == month }) {
            return BillDraft(month: month, previousWater: bill.previousWater, currentWater: bill.currentWater,
                previousElectricity: bill.previousElectricity, currentElectricity: bill.currentElectricity,
                waterUsageOverride: historicalUsageOverride(bill.waterUsage, current: bill.currentWater, previous: bill.previousWater),
                electricityUsageOverride: historicalUsageOverride(bill.electricityUsage, current: bill.currentElectricity, previous: bill.previousElectricity),
                customCharges: bill.customCharges)
        }
        var value = BillDraft(month: month, customCharges: room.recurringCharges)
        if let previous = data.bills.filter({ $0.buildingId == room.buildingId && $0.roomId == room.id && $0.month < month }).max(by: { $0.month < $1.month }) {
            value.previousWater = previous.currentWater; value.previousElectricity = previous.currentElectricity
        }
        return value
    }

    private func historicalUsageOverride(_ usage: String, current: String, previous: String) -> String? {
        guard !usage.isEmpty, let actual = try? BillCalculator.decimal(usage),
              let currentValue = try? BillCalculator.decimal(current), let previousValue = try? BillCalculator.decimal(previous) else { return nil }
        return actual == BillCalculator.rounded(currentValue - previousValue) ? nil : usage
    }

    func draft(roomID: String, month: String) -> BillDraft? { drafts[draftKey(roomID, month)] }
    func saveDraft(_ draft: BillDraft, roomID: String) {
        drafts[draftKey(roomID, draft.month)] = draft
        saveDrafts()
        if [draft.previousWater, draft.currentWater, draft.previousElectricity, draft.currentElectricity].contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            data.bills.removeAll { $0.buildingId == selectedBuildingID && $0.roomId == roomID && $0.month == draft.month }
            persist()
        }
    }

    func replaceAll(with replacement: AppData) {
        drafts = [:]
        saveDrafts()
        data = replacement
        if data.buildings.isEmpty { data.buildings = [.init(id: defaultBuildingID, name: "默认楼栋")] }
        selectedBuildingID = data.buildings[0].id
        persist()
    }

    func flush() { pendingSave?.cancel(); saveNow() }

    private func persist() {
        objectWillChange.send()
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    private func saveNow() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(data).write(to: fileURL, options: .atomic)
            lastPersistenceError = nil
        } catch { lastPersistenceError = "数据保存失败：\(error.localizedDescription)" }
    }

    private static func load(from url: URL) -> AppData {
        guard let bytes = try? Data(contentsOf: url), let value = try? JSONDecoder().decode(AppData.self, from: bytes) else {
            return AppData()
        }
        return value
    }

    private func draftKey(_ roomID: String, _ month: String) -> String { "\(selectedBuildingID)|\(roomID)|\(month)" }
    private var draftURL: URL { fileURL.deletingLastPathComponent().appendingPathComponent("drafts.json") }
    private func loadDrafts() {
        guard let bytes = try? Data(contentsOf: draftURL) else { return }
        drafts = (try? JSONDecoder().decode([String: BillDraft].self, from: bytes)) ?? [:]
    }
    @discardableResult
    private func saveDrafts() -> Bool {
        do {
            try FileManager.default.createDirectory(at: draftURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(drafts).write(to: draftURL, options: .atomic)
            return true
        } catch {
            lastPersistenceError = "草稿保存失败：\(error.localizedDescription)"
            return false
        }
    }
}
