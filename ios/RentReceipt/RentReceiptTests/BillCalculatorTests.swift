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

    func testBackupVersionEightRoundTrip() throws {
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
}
