import Foundation

enum BillValidationError: LocalizedError, Equatable {
    case message(String)
    var errorDescription: String? {
        if case let .message(value) = self { value } else { nil }
    }
}

struct BillCalculation: Equatable {
    var waterUsage: Decimal
    var electricityUsage: Decimal
    var waterAmount: Decimal
    var electricityAmount: Decimal
    var total: Decimal
    var managementAmount: Decimal = 0
}

enum BillCalculator {
    static func nextEmptyReading(_ drafts: [BillDraft], after: Int) -> Int? {
        let values = drafts.flatMap { [$0.previousWater, $0.currentWater, $0.previousElectricity, $0.currentElectricity] }
        return values.indices.first { $0 > after && values[$0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    static func calculate(room: Room, settings: PricingSettings, draft: BillDraft) throws -> BillCalculation {
        let customChargeTotal = try draft.customCharges.reduce(Decimal.zero) { partial, charge in
            guard !charge.name.trimmingCharacters(in: .whitespaces).isEmpty, !charge.amount.isEmpty else {
                throw BillValidationError.message("请填写其他收费项的名称和金额")
            }
            let amount = try decimal(charge.amount, "其他收费项金额")
            guard amount >= 0 else { throw BillValidationError.message("其他收费项金额不能为负数") }
            return partial + rounded(amount)
        }
        if draft.rentOnly {
            guard !draft.currentWater.isEmpty, !draft.currentElectricity.isEmpty else {
                throw BillValidationError.message("请填写入住时的水电表读数")
            }
            let water = try decimal(draft.currentWater, "水表读数")
            let electricity = try decimal(draft.currentElectricity, "电表读数")
            guard water >= 0, electricity >= 0 else {
                throw BillValidationError.message("入住时的水电表读数不能为负数")
            }
            let rent = try decimal(room.rent, "房租")
            guard rent >= 0 else { throw BillValidationError.message("房租不能为负数") }
            return .init(waterUsage: 0, electricityUsage: 0, waterAmount: 0, electricityAmount: 0, total: rounded(rent + customChargeTotal))
        }

        guard !draft.previousWater.isEmpty, !draft.currentWater.isEmpty,
              !draft.previousElectricity.isEmpty, !draft.currentElectricity.isEmpty else {
            throw BillValidationError.message("请填写完整的本月和上月水电读数")
        }
        let previousWater = try decimal(draft.previousWater, "上月水表")
        let currentWater = try decimal(draft.currentWater, "本月水表")
        let previousElectricity = try decimal(draft.previousElectricity, "上月电表")
        let currentElectricity = try decimal(draft.currentElectricity, "本月电表")
        let waterUsage = try meterUsage(previous: previousWater, current: currentWater,
            meterMax: room.customWaterMeterMax ?? settings.defaultWaterMeterMax,
            override: draft.waterUsageOverride, label: "水表")
        let electricityUsage = try meterUsage(previous: previousElectricity, current: currentElectricity,
            meterMax: room.customElectricityMeterMax ?? settings.defaultElectricityMeterMax,
            override: draft.electricityUsageOverride, label: "电表")
        let waterRate = try decimal(room.customWaterRate ?? settings.defaultWaterRate, "水价")
        let electricityRate = try decimal(room.customElectricityRate ?? settings.defaultElectricityRate, "电价")
        let rent = try decimal(room.rent, "房租")
        guard waterRate >= 0, electricityRate >= 0 else { throw BillValidationError.message("水电单价不能为负数") }
        guard rent >= 0 else { throw BillValidationError.message("房租不能为负数") }
        let waterAmount = rounded(waterUsage * waterRate)
        let electricityAmount = rounded(electricityUsage * electricityRate)
        let managementText = (room.customManagementRate ?? settings.defaultManagementRate)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let managementRate = try managementText.flatMap { $0.isEmpty ? nil : $0 }.map { try decimal($0, "公共服务费单价") } ?? 0
        guard managementRate >= 0 else { throw BillValidationError.message("公共服务费单价不能为负数") }
        let managementAmount = rounded(electricityUsage * managementRate)
        return .init(waterUsage: rounded(waterUsage), electricityUsage: rounded(electricityUsage),
                     waterAmount: waterAmount, electricityAmount: electricityAmount,
                     total: rounded(rent + waterAmount + electricityAmount + managementAmount + customChargeTotal), managementAmount: managementAmount)
    }

    static func makeBill(room: Room, settings: PricingSettings, draft: BillDraft) throws -> Bill {
        guard MonthValue.parse(draft.month) != nil else { throw BillValidationError.message("月份格式错误") }
        let value = try calculate(room: room, settings: settings, draft: draft)
        let previousWater = draft.rentOnly ? draft.currentWater : draft.previousWater
        let previousElectricity = draft.rentOnly ? draft.currentElectricity : draft.previousElectricity
        return Bill(buildingId: room.buildingId, roomId: room.id, roomNumber: room.number,
                    month: draft.month, createdDate: "\(draft.month)-01",
                    previousWater: text(try decimal(previousWater)), currentWater: text(try decimal(draft.currentWater)),
                    waterRate: normalized(room.customWaterRate ?? settings.defaultWaterRate), waterAmount: text(value.waterAmount),
                    previousElectricity: text(try decimal(previousElectricity)), currentElectricity: text(try decimal(draft.currentElectricity)),
                    electricityRate: normalized(room.customElectricityRate ?? settings.defaultElectricityRate), electricityAmount: text(value.electricityAmount),
                    rent: text(try decimal(room.rent, "房租")), total: text(value.total), rentOnly: draft.rentOnly,
                    waterUsage: text(value.waterUsage), electricityUsage: text(value.electricityUsage),
                    customCharges: try draft.customCharges.map { CustomCharge(name: $0.name.trimmingCharacters(in: .whitespaces), amount: text(try decimal($0.amount))) },
                    managementRate: (room.customManagementRate ?? settings.defaultManagementRate).flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : normalized($0) },
                    managementAmount: text(value.managementAmount))
    }

    static func decimal(_ text: String, _ label: String = "数字") throws -> Decimal {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard input.range(of: #"^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?$"#, options: .regularExpression) != nil,
              let value = Decimal(string: input, locale: Locale(identifier: "en_US_POSIX")), !value.isNaN else {
            throw BillValidationError.message("\(label)格式错误")
        }
        return value
    }

    static func rounded(_ value: Decimal) -> Decimal {
        var source = value
        var result = Decimal()
        NSDecimalRound(&result, &source, 0, .plain)
        return result
    }

    static func text(_ value: Decimal) -> String { NSDecimalNumber(decimal: rounded(value)).stringValue }
    static func normalized(_ value: String) -> String {
        guard let decimal = Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) else { return value }
        return NSDecimalNumber(decimal: decimal).stringValue
    }

    private static func meterUsage(previous: Decimal, current: Decimal, meterMax: String?, override: String?, label: String) throws -> Decimal {
        if let override, !override.isEmpty {
            let actual = try decimal(override, "\(label)换表用量")
            guard actual >= 0 else { throw BillValidationError.message("\(label)换表用量不能为负数") }
            return actual
        }
        if current >= previous { return current - previous }
        guard let meterMax, !meterMax.isEmpty else {
            throw BillValidationError.message("\(label)读数变小，请设置归零上限或填写换表实际用量")
        }
        let maximum = try decimal(meterMax, "\(label)归零上限")
        guard maximum > previous, current >= 0 else { throw BillValidationError.message("\(label)归零上限设置无效") }
        return maximum - previous + current
    }
}

// Compare effective fees numerically; meter settings do not change saved usage.
extension Room {
    func billingFees(_ settings: PricingSettings) -> [String] {
        [rent, customWaterRate ?? settings.defaultWaterRate,
         customElectricityRate ?? settings.defaultElectricityRate,
         customManagementRate ?? settings.defaultManagementRate ?? "0"].map { BillCalculator.normalized($0.isEmpty ? "0" : $0) }
        + recurringCharges.flatMap { [$0.name.trimmingCharacters(in: .whitespaces), BillCalculator.normalized($0.amount)] }
    }
}

extension Bill {
    func repriced(room: Room, settings: PricingSettings, previousRoom: Room) throws -> Bill {
        var charges = customCharges
        if previousRoom.recurringCharges != room.recurringCharges {
            for old in previousRoom.recurringCharges {
                if let index = charges.firstIndex(where: {
                    $0.name == old.name.trimmingCharacters(in: .whitespaces) &&
                    BillCalculator.normalized($0.amount) == BillCalculator.text((try? BillCalculator.decimal(old.amount)) ?? 0)
                }) { charges.remove(at: index) }
            }
            charges += room.recurringCharges
        }
        let draft = BillDraft(month: month, previousWater: previousWater, currentWater: currentWater,
            previousElectricity: previousElectricity, currentElectricity: currentElectricity,
            rentOnly: rentOnly, waterUsageOverride: waterUsage.isEmpty ? BillCalculator.text(try BillCalculator.decimal(currentWater) - BillCalculator.decimal(previousWater)) : waterUsage,
            electricityUsageOverride: electricityUsage.isEmpty ? BillCalculator.text(try BillCalculator.decimal(currentElectricity) - BillCalculator.decimal(previousElectricity)) : electricityUsage, customCharges: charges)
        var result = try BillCalculator.makeBill(room: room, settings: settings, draft: draft)
        result.id = id; result.createdDate = createdDate; result.paid = paid; result.paidDate = paidDate
        return result
    }
}
