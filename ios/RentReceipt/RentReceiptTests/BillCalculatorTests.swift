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
