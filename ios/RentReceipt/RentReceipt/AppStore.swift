import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var data: AppData
    @Published var selectedBuildingID: String
    @Published private(set) var lastPersistenceError: String?

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
        for index in data.bills.indices where data.bills[index].buildingId == selectedBuildingID && data.bills[index].month == month {
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

    func draft(roomID: String, month: String) -> BillDraft? { drafts[draftKey(roomID, month)] }
    func saveDraft(_ draft: BillDraft, roomID: String) {
        drafts[draftKey(roomID, draft.month)] = draft
        saveDrafts()
    }

    func replaceAll(with replacement: AppData) {
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
    private func saveDrafts() {
        do {
            try FileManager.default.createDirectory(at: draftURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(drafts).write(to: draftURL, options: .atomic)
        } catch {
            lastPersistenceError = "草稿保存失败：\(error.localizedDescription)"
        }
    }
}
