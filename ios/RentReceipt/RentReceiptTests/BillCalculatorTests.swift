import XCTest
@testable import RentReceipt

final class BillCalculatorTests: XCTestCase {
    func testStandardBillMatchesAndroidRules() throws {
        let room = Room(number: "201", rent: "800", buildingId: defaultBuildingID)
        let draft = BillDraft(month: "2026-08", previousWater: "100", currentWater: "112",
                              previousElectricity: "1000", currentElectricity: "1060")
        let bill = try BillCalculator.makeBill(room: room, settings: PricingSettings(), draft: draft)
        XCTAssertEqual(bill.waterUsage, "12")
        XCTAssertEqual(bill.waterAmount, "60")
        XCTAssertEqual(bill.electricityUsage, "60")
        XCTAssertEqual(bill.electricityAmount, "78")
        XCTAssertEqual(bill.total, "938")
    }

    func testMeterWrapAndCustomCharge() throws {
        let room = Room(number: "铺1", rent: "1000", buildingId: defaultBuildingID)
        let draft = BillDraft(month: "2026-08", previousWater: "990", currentWater: "10",
                              previousElectricity: "9990", currentElectricity: "5",
                              customCharges: [CustomCharge(name: "卫生费", amount: "20")])
        var settings = PricingSettings()
        settings.defaultWaterMeterMax = "1000"
        let bill = try BillCalculator.makeBill(room: room, settings: settings, draft: draft)
        XCTAssertEqual(bill.waterUsage, "20")
        XCTAssertEqual(bill.electricityUsage, "15")
        XCTAssertEqual(bill.total, "1140")
        XCTAssertEqual(bill.customCharges.first?.amount, "20")
    }

    func testRentOnlyRequiresMoveInReadings() {
        let room = Room(number: "101", rent: "800", buildingId: defaultBuildingID)
        XCTAssertThrowsError(try BillCalculator.calculate(room: room, settings: PricingSettings(), draft: BillDraft(month: "2026-08", rentOnly: true)))
    }

    func testSkippedMonthCanBeMergedIntoCurrentBill() throws {
        let missing = MonthValue.missingBillMonths(previous: "2026-01", target: .init(year: 2026, month: 3))
        XCTAssertEqual(missing, [.init(year: 2026, month: 2)])
        let room = Room(number: "101", rent: "800", buildingId: defaultBuildingID)
        let draft = BillDraft(
            month: "2026-03",
            previousWater: "100", currentWater: "110",
            previousElectricity: "1000", currentElectricity: "1050"
        ).withMergedRent(room.rent, months: missing)
        let bill = try BillCalculator.makeBill(room: room, settings: PricingSettings(), draft: draft)
        XCTAssertEqual(bill.total, "1715")
        XCTAssertEqual(bill.customCharges.count, 1)
        XCTAssertEqual(bill.customCharges.first?.name, "补收房租·2026年2月")
    }

    func testBackupVersionTenRoundTrip() throws {
        let building = Building(id: "building-a", name: "文明楼")
        let room = Room(id: "room-101", number: "101", rent: "800", buildingId: building.id, occupied: true,
                        depositAmount: "800", depositStatus: .collected)
        let bill = Bill(buildingId: building.id, roomId: room.id, roomNumber: room.number, month: "2026-08", createdDate: "2026-08-01",
                        previousWater: "10", currentWater: "20", waterRate: "5", waterAmount: "50",
                        previousElectricity: "100", currentElectricity: "200", electricityRate: "1.3", electricityAmount: "130",
                        rent: "800", total: "1000", waterUsage: "10", electricityUsage: "100",
                        customCharges: [CustomCharge(name: "卫生费", amount: "20")])
        let original = AppData(buildings: [building], rooms: [room], bills: [bill])
        let restored = try BackupArchive.importArchive(from: BackupArchive.export(original))
        XCTAssertEqual(restored.buildings.first?.name, "文明楼")
        XCTAssertEqual(restored.rooms.first?.depositStatus, .collected)
        XCTAssertEqual(restored.bills.first?.customCharges.first?.name, "卫生费")
        XCTAssertEqual(restored.bills.first?.total, "1000")
    }

    func testImportsCompressedAndroidVersionSixBackup() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "AndroidV6Fixture", withExtension: "zip"))
        let restored = try BackupArchive.importArchive(from: url)
        XCTAssertEqual(restored.buildings.first?.name, "文明")
        XCTAssertGreaterThan(restored.rooms.count, 10)
        XCTAssertGreaterThan(restored.bills.count, 10)
    }

    func testManagementFeeMatchesAndroidAndUsesActualUsage() throws {
        let room = Room(number: "101", rent: "500")
        let settings = PricingSettings(defaultManagementRate: "0.25")
        var draft = BillDraft(month: "2026-08", previousWater: "1", currentWater: "1", previousElectricity: "100", currentElectricity: "234")
        let bill = try BillCalculator.makeBill(room: room, settings: settings, draft: draft)
        XCTAssertEqual(bill.managementRate, "0.25")
        XCTAssertEqual(bill.managementAmount, "34")
        XCTAssertEqual(bill.total, "708")
        XCTAssertEqual(try BillCalculator.makeBill(room: room, settings: PricingSettings(), draft: draft).managementAmount, "0")
        draft.previousElectricity = "9900"; draft.currentElectricity = "100"
        XCTAssertEqual(try BillCalculator.makeBill(room: room, settings: settings, draft: draft).managementAmount, "50")
        draft.electricityUsageOverride = "50"
        XCTAssertEqual(try BillCalculator.makeBill(room: room, settings: settings, draft: draft).managementAmount, "13")
        draft.rentOnly = true
        XCTAssertEqual(try BillCalculator.makeBill(room: room, settings: settings, draft: draft).total, "500")
        draft.rentOnly = false
        XCTAssertThrowsError(try BillCalculator.calculate(room: room, settings: PricingSettings(defaultManagementRate: "-0.2"), draft: draft))
    }

    func testOldLocalJSONDecodesWithoutManagementFields() throws {
        let room = Room(number: "101", rent: "500")
        let bill = try BillCalculator.makeBill(room: room, settings: PricingSettings(), draft: BillDraft(month: "2026-08", previousWater: "1", currentWater: "2", previousElectricity: "1", currentElectricity: "2"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(bill)) as? [String: Any])
        json.removeValue(forKey: "managementRate"); json.removeValue(forKey: "managementAmount")
        let restored = try JSONDecoder().decode(Bill.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(restored.managementRate)
        XCTAssertEqual(restored.managementAmount, "0")
        XCTAssertEqual(restored.total, bill.total)
        let settingsJSON = Data(#"{"defaultWaterRate":"5","defaultElectricityRate":"1.3","defaultElectricityMeterMax":"10000"}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(PricingSettings.self, from: settingsJSON).defaultManagementRate)
    }

    func testImportsAllLegacyVersionsAndAndroidVersionNine() throws {
        for version in 1...10 {
            let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "AndroidV\(version)", withExtension: "zip", subdirectory: "BackupFixtures"))
            let restored = try BackupArchive.importArchive(from: url)
            let bill = try XCTUnwrap(restored.bills.first)
            XCTAssertEqual(restored.rooms.first?.number, "604,东")
            XCTAssertEqual(bill.total, version >= 9 ? "898" : version >= 8 ? "864" : "834")
            XCTAssertEqual(bill.managementAmount, version >= 9 ? "34" : "0")
            XCTAssertEqual(bill.managementRate, version >= 9 ? "0.25" : nil)
            XCTAssertEqual(restored.buildings.first?.settings.defaultManagementRate, version >= 9 ? "0.25" : nil)
            XCTAssertEqual(bill.paid, version >= 4)
            if version >= 8 { XCTAssertEqual(bill.customCharges.first?.name, "门卡,补办") }
            if version >= 3 { XCTAssertEqual(restored.receiptTemplate.elements.first?.content, "旧标题") }
            XCTAssertEqual(restored.rooms.first?.customManagementRate, version >= 10 ? "0.6" : nil)
            XCTAssertEqual(restored.rooms.first?.recurringCharges.first?.name, version >= 10 ? "网络费" : nil)
            let again = try BackupArchive.importArchive(from: BackupArchive.export(restored))
            XCTAssertEqual(again.buildings, restored.buildings)
            XCTAssertEqual(again.rooms.first?.number, restored.rooms.first?.number)
            XCTAssertEqual(again.rooms.first?.customManagementRate, restored.rooms.first?.customManagementRate)
            XCTAssertEqual(again.rooms.first?.recurringCharges.first?.amount, restored.rooms.first?.recurringCharges.first?.amount)
            XCTAssertEqual(again.bills.first?.total, bill.total)
            XCTAssertEqual(again.bills.first?.managementAmount, bill.managementAmount)
        }
    }

    func testReceiptAddsManagementRowAndSupportsOldTemplate() throws {
        let room = Room(number: "101", rent: "500")
        let draft = BillDraft(month: "2026-08", previousWater: "1", currentWater: "2", previousElectricity: "1", currentElectricity: "101")
        let plain = try BillCalculator.makeBill(room: room, settings: PricingSettings(), draft: draft)
        let managed = try BillCalculator.makeBill(room: room, settings: PricingSettings(defaultManagementRate: "0.25"), draft: draft)
        let oldTemplate = ReceiptTemplate(elements: ReceiptTemplate.defaultElements.filter { !["headRate", "waterRate", "electricRate"].contains($0.id) })
        XCTAssertEqual(ReceiptRenderer.image(for: plain, buildingName: "东楼").size.height, ReceiptRenderer.baseHeight)
        let image = ReceiptRenderer.image(for: managed, buildingName: "东楼", template: oldTemplate)
        XCTAssertEqual(image.size.height, ReceiptRenderer.baseHeight + ReceiptRenderer.customRowHeight)
        let attachment = XCTAttachment(image: image)
        attachment.name = "管理费收据预览"
        attachment.lifetime = .keepAlways
        add(attachment)
        let url = try ReceiptRenderer.writeTemporaryPNG(image, for: managed)
        XCTAssertGreaterThan(try Data(contentsOf: url).count, 1000)
    }

    func testRoomServiceFeeOverridesDefaultAndOldRoomJSONRestores() throws {
        let room = Room(number: "101", rent: "500", customManagementRate: "0.6", recurringCharges: [CustomCharge(name: "网络费", amount: "30")])
        let draft = BillDraft(month: "2026-08", previousWater: "1", currentWater: "1", previousElectricity: "100", currentElectricity: "234", customCharges: room.recurringCharges)
        let settings = PricingSettings(defaultElectricityRate: "0.7", defaultManagementRate: "0.2")
        let bill = try BillCalculator.makeBill(room: room, settings: settings, draft: draft)
        XCTAssertEqual(bill.managementAmount, "80")
        XCTAssertEqual(bill.total, "704")
        var freeRoom = room; freeRoom.customManagementRate = "0"
        XCTAssertEqual(try BillCalculator.makeBill(room: freeRoom, settings: settings, draft: draft).managementAmount, "0")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(room)) as? [String: Any])
        json.removeValue(forKey: "customManagementRate"); json.removeValue(forKey: "recurringCharges")
        let oldRoom = try JSONDecoder().decode(Room.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(oldRoom.customManagementRate)
        XCTAssertTrue(oldRoom.recurringCharges.isEmpty)
        XCTAssertEqual(oldRoom.number, room.number)
    }
}

extension BillCalculatorTests {
    func testContinueSkipsCompletedReadingsAcrossRooms() {
        let first = BillDraft(month: "2026-08", previousWater: "1", currentWater: "2", previousElectricity: "3")
        let second = BillDraft(month: "2026-08", previousWater: "4", currentWater: " ", previousElectricity: "5", currentElectricity: "6")
        XCTAssertEqual(BillCalculator.nextEmptyReading([first, second], after: 0), 3)
        XCTAssertEqual(BillCalculator.nextEmptyReading([first, second], after: 3), 5)
        XCTAssertNil(BillCalculator.nextEmptyReading([first, second], after: 5))
    }

    func testRepricingPreservesActualUsageIdentityPaymentAndManualCharges() throws {
        let room = Room(number: "101", rent: "650", recurringCharges: [.init(name: "网费", amount: "30")])
        let draft = BillDraft(month: "2026-08", previousWater: "100", currentWater: "102",
            previousElectricity: "1000", currentElectricity: "1100", waterUsageOverride: "8",
            customCharges: room.recurringCharges + [.init(name: "临时收费", amount: "20"), .init(name: "补收房租", amount: "650")])
        var bill = try BillCalculator.makeBill(room: room, settings: PricingSettings(), draft: draft)
        bill.paid = true; bill.paidDate = "2026-08-03"; bill.createdDate = "2026-08-02"
        var updated = room; updated.rent = "700"; updated.recurringCharges = [.init(name: "网费", amount: "40")]
        let result = try bill.repriced(room: updated, settings: PricingSettings(), previousRoom: room)
        XCTAssertEqual(result.waterUsage, "8"); XCTAssertEqual(result.id, bill.id)
        XCTAssertEqual(result.createdDate, bill.createdDate); XCTAssertEqual(result.paidDate, bill.paidDate); XCTAssertTrue(result.paid)
        XCTAssertEqual(result.customCharges.map(\.name), ["临时收费", "补收房租", "网费"])
        XCTAssertEqual(result.customCharges.map(\.amount), ["20", "650", "40"])
    }

    @MainActor
    func testClearingEntryRemovesOnlyMatchingBillAcrossReload() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("data.json"), store = AppStore(fileURL: folder.appendingPathComponent("data.json"))
        let room = Room(number: "101", rent: "650")
        store.upsert(room)
        var draft = BillDraft(month: "2026-08", previousWater: "100", currentWater: "102", previousElectricity: "1000", currentElectricity: "1100")
        store.upsert(try BillCalculator.makeBill(room: room, settings: PricingSettings(), draft: draft))
        draft.month = "2026-07"
        store.upsert(try BillCalculator.makeBill(room: room, settings: PricingSettings(), draft: draft))
        draft.month = "2026-08"; draft.currentWater = ""
        store.saveDraft(draft, roomID: room.id); store.flush()
        let reopened = AppStore(fileURL: url)
        XCTAssertEqual(reopened.data.bills.map(\.month), ["2026-07"])
        XCTAssertEqual(reopened.draft(roomID: room.id, month: "2026-08")?.currentWater, "")
    }

    @MainActor
    func testFeeConfirmationDoesNotChangeBillUntilAccepted() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = AppStore(fileURL: folder.appendingPathComponent("data.json"))
        let room = Room(number: "101", rent: "650", customWaterRate: "7")
        store.upsert(room); store.readingMonth = MonthValue.parse("2026-07")!
        let draft = BillDraft(month: "2026-08", previousWater: "100", currentWater: "102", previousElectricity: "1000", currentElectricity: "1100")
        let bill = try BillCalculator.makeBill(room: room, settings: PricingSettings(), draft: draft)
        store.saveDraft(draft, roomID: room.id); store.upsert(bill)
        var previous = store.data, settings = store.selectedBuilding.settings
        settings.defaultWaterRate = "9"; store.updateSettings(settings); store.prepareReexport(previous: previous)
        XCTAssertTrue(store.pendingReexport.isEmpty)
        previous = store.data; settings.defaultElectricityRate = "2"
        store.updateSettings(settings); store.prepareReexport(previous: previous)
        XCTAssertEqual(store.pendingReexport.count, 1)
        XCTAssertEqual(store.data.bills.first?.electricityAmount, "130")
        store.pendingReexport = [] // 暂不导出
        XCTAssertEqual(store.data.bills.first?.electricityAmount, "130")
        store.prepareReexport(previous: previous)
        store.saveRepricedBills(store.pendingReexport)
        XCTAssertEqual(store.data.bills.first?.electricityAmount, "200")
        XCTAssertEqual(store.data.bills.first?.id, bill.id)
        store.flush()
    }

    @MainActor
    func testRepricingReportsDraftWriteFailureEvenWhenBillSaveSucceeds() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = AppStore(fileURL: folder.appendingPathComponent("data.json"))
        let room = Room(number: "101", rent: "650")
        store.upsert(room)
        let draft = BillDraft(month: "2026-08", previousWater: "100", currentWater: "102", previousElectricity: "1000", currentElectricity: "1100")
        let bill = try BillCalculator.makeBill(room: room, settings: PricingSettings(), draft: draft)
        store.upsert(bill); store.saveDraft(draft, roomID: room.id); store.flush()
        let draftURL = folder.appendingPathComponent("drafts.json")
        try FileManager.default.removeItem(at: draftURL)
        try FileManager.default.createDirectory(at: draftURL, withIntermediateDirectories: false)
        store.saveRepricedBills([bill])
        XCTAssertNotNil(store.lastPersistenceError)
        XCTAssertTrue(store.lastPersistenceError?.contains("草稿保存失败") == true)
    }


    @MainActor
    func testImportedMeterCorrectionsSeedEntryWithoutFreezingOrdinaryReadings() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = AppStore(fileURL: folder.appendingPathComponent("data.json"))
        let room = Room(number: "101", rent: "1000")
        store.upsert(room)
        var draft = BillDraft(month: "2026-11", previousWater: "110", currentWater: "120", previousElectricity: "1100", currentElectricity: "1200", waterUsageOverride: "8", electricityUsageOverride: "50")
        store.upsert(try BillCalculator.makeBill(room: room, settings: PricingSettings(), draft: draft))
        let corrected = store.entryDraft(room: room, month: draft.month)
        XCTAssertEqual(corrected.waterUsageOverride, "8"); XCTAssertEqual(corrected.electricityUsageOverride, "50")
        draft.month = "2026-12"; draft.waterUsageOverride = nil; draft.electricityUsageOverride = nil
        store.upsert(try BillCalculator.makeBill(room: room, settings: PricingSettings(), draft: draft))
        var ordinary = store.entryDraft(room: room, month: draft.month)
        XCTAssertNil(ordinary.waterUsageOverride)
        ordinary.currentWater = "125"
        XCTAssertEqual(try BillCalculator.makeBill(room: room, settings: PricingSettings(), draft: ordinary).waterUsage, "15")
        store.flush()
    }

}
