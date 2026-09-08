import Foundation

let defaultBuildingID = "default-building"

struct PricingSettings: Codable, Equatable {
    var defaultWaterRate = "5.00"
    var defaultElectricityRate = "1.30"
    var defaultWaterMeterMax: String?
    var defaultElectricityMeterMax: String? = "10000"
}

struct ReceiptTextElement: Codable, Identifiable, Equatable {
    var id: String
    var content: String
    var x: Double
    var y: Double
    var fontSize: Double
    var centered = false
    var color = "body"
}

struct ReceiptTemplate: Codable, Equatable {
    var elements: [ReceiptTextElement] = Self.defaultElements

    static let defaultElements: [ReceiptTextElement] = [
        .init(id: "title", content: "公寓房租、水、电费（专用）收据", x: 1754, y: 125, fontSize: 108, centered: true),
        .init(id: "userLabel", content: "用户名称：", x: 95, y: 245, fontSize: 66),
        .init(id: "room", content: "{room}", x: 405, y: 245, fontSize: 148, color: "blue"),
        .init(id: "roomSuffix", content: "号", x: 700, y: 245, fontSize: 66),
        .init(id: "receiptNo", content: "№  {receiptNo}", x: 2760, y: 150, fontSize: 76, color: "red"),
        .init(id: "date", content: "{date}", x: 2700, y: 265, fontSize: 90, color: "blue"),
        .init(id: "headItem", content: "项  目", x: 337, y: 435, fontSize: 66, centered: true),
        .init(id: "headCurrent", content: "本  月", x: 777, y: 435, fontSize: 66, centered: true),
        .init(id: "headPrevious", content: "上  月", x: 1172, y: 435, fontSize: 66, centered: true),
        .init(id: "headUsage", content: "实  用", x: 1567, y: 435, fontSize: 66, centered: true),
        .init(id: "headAmount", content: "金      额", x: 2799, y: 435, fontSize: 66, centered: true),
        .init(id: "waterLabel", content: "水费（立方米）", x: 337, y: 700, fontSize: 66, centered: true),
        .init(id: "waterCurrent", content: "{currentWater}", x: 777, y: 720, fontSize: 136, centered: true, color: "blue"),
        .init(id: "waterPrevious", content: "{previousWater}", x: 1172, y: 720, fontSize: 136, centered: true, color: "blue"),
        .init(id: "waterUsage", content: "{waterUsage}", x: 1567, y: 720, fontSize: 136, centered: true, color: "blue"),
        .init(id: "waterAmount", content: "{waterAmount}", x: 2799, y: 725, fontSize: 136, centered: true, color: "blue"),
        .init(id: "electricLabel", content: "电费（度）", x: 337, y: 1000, fontSize: 66, centered: true),
        .init(id: "electricCurrent", content: "{currentElectricity}", x: 777, y: 1020, fontSize: 136, centered: true, color: "blue"),
        .init(id: "electricPrevious", content: "{previousElectricity}", x: 1172, y: 1020, fontSize: 136, centered: true, color: "blue"),
        .init(id: "electricUsage", content: "{electricityUsage}", x: 1567, y: 1020, fontSize: 136, centered: true, color: "blue"),
        .init(id: "electricAmount", content: "{electricityAmount}", x: 2799, y: 1025, fontSize: 136, centered: true, color: "blue"),
        .init(id: "rentLabel", content: "房  租", x: 337, y: 1300, fontSize: 66, centered: true),
        .init(id: "rentUsage", content: "{rent}", x: 1567, y: 1325, fontSize: 136, centered: true, color: "blue"),
        .init(id: "rentAmount", content: "{rent}", x: 2799, y: 1325, fontSize: 136, centered: true, color: "blue"),
        .init(id: "totalLabel", content: "合  计（大写）", x: 155, y: 1635, fontSize: 64),
        .init(id: "totalUpper", content: "{totalUpper}", x: 720, y: 1695, fontSize: 140, color: "blue"),
        .init(id: "total", content: "¥ {total}", x: 2720, y: 1705, fontSize: 168, color: "blue")
    ]
}

struct Building: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var name: String
    var settings = PricingSettings()
    var receiptTemplate: ReceiptTemplate?
}

enum DepositStatus: String, Codable, CaseIterable, Identifiable {
    case notCollected = "NOT_COLLECTED"
    case collected = "COLLECTED"
    case refunded = "REFUNDED"

    var id: Self { self }
    var title: String {
        switch self {
        case .notCollected: "未收"
        case .collected: "已收"
        case .refunded: "已退"
        }
    }
}

struct Room: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var number: String
    var rent: String
    var customWaterRate: String?
    var customElectricityRate: String?
    var buildingId = defaultBuildingID
    var occupied = false
    var depositAmount = "0"
    var depositStatus = DepositStatus.notCollected
    var depositCollectedDate: String?
    var depositRefundedDate: String?
    var customWaterMeterMax: String?
    var customElectricityMeterMax: String?
}

struct Bill: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var buildingId = defaultBuildingID
    var roomId: String
    var roomNumber: String
    var month: String
    var createdDate: String
    var previousWater: String
    var currentWater: String
    var waterRate: String
    var waterAmount: String
    var previousElectricity: String
    var currentElectricity: String
    var electricityRate: String
    var electricityAmount: String
    var rent: String
    var total: String
    var rentOnly = false
    var paid = false
    var paidDate: String?
    var waterUsage = ""
    var electricityUsage = ""
    var customCharges: [CustomCharge] = []
}

struct CustomCharge: Codable, Equatable, Identifiable {
    var id = UUID()
    var name = ""
    var amount = ""

    enum CodingKeys: String, CodingKey { case name, amount }
}

struct BillDraft: Codable, Equatable {
    var month: String
    var previousWater = ""
    var currentWater = ""
    var previousElectricity = ""
    var currentElectricity = ""
    var rentOnly = false
    var waterUsageOverride: String?
    var electricityUsageOverride: String?
    var customCharges: [CustomCharge] = []
}

let mergedRentChargePrefix = "补收房租·"

extension BillDraft {
    func withMergedRent(_ roomRent: String, months: [MonthValue]) -> BillDraft {
        var value = self
        value.rentOnly = false
        let manualCharges = customCharges.filter { !$0.name.hasPrefix(mergedRentChargePrefix) }
        let mergedCharges = months.map {
            CustomCharge(name: "\(mergedRentChargePrefix)\($0.year)年\($0.month)月", amount: roomRent)
        }
        value.customCharges = manualCharges + mergedCharges
        return value
    }
}

struct AppData: Codable, Equatable {
    var buildings: [Building] = [.init(id: defaultBuildingID, name: "默认楼栋")]
    var rooms: [Room] = []
    var bills: [Bill] = []
    var receiptTemplate = ReceiptTemplate()
}

extension Room {
    static func ordered(_ lhs: Room, _ rhs: Room) -> Bool {
        let leftShop = lhs.number.trimmingCharacters(in: .whitespaces).hasPrefix("铺") || lhs.number.hasPrefix("店")
        let rightShop = rhs.number.trimmingCharacters(in: .whitespaces).hasPrefix("铺") || rhs.number.hasPrefix("店")
        if leftShop != rightShop { return leftShop }
        let leftNumber = Int(lhs.number.filter(\.isNumber)) ?? .max
        let rightNumber = Int(rhs.number.filter(\.isNumber)) ?? .max
        if leftNumber != rightNumber { return leftNumber < rightNumber }
        return lhs.number.localizedStandardCompare(rhs.number) == .orderedAscending
    }
}

extension Date {
    static let isoDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
