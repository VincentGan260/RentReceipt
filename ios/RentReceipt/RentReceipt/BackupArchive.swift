import Foundation
import zlib

enum BackupError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(text) = self { text } else { nil } }
}

enum BackupArchive {
    static func export(_ appData: AppData) throws -> URL {
        var files: [String: Data] = [:]
        files["manifest.csv"] = csv([["format", "version"], ["rent-receipt", "8"]])
        files["buildings.csv"] = csv([["id", "name", "default_water_rate", "default_electricity_rate", "default_water_meter_max", "default_electricity_meter_max"]] + appData.buildings.map {
            [$0.id, $0.name, $0.settings.defaultWaterRate, $0.settings.defaultElectricityRate, $0.settings.defaultWaterMeterMax ?? "", $0.settings.defaultElectricityMeterMax ?? ""]
        })
        var templateRows = [["scope", "building_id", "id", "content", "x", "y", "font_size", "centered", "color"]]
        templateRows += appData.receiptTemplate.elements.map { templateRow($0, "global", "") }
        for building in appData.buildings {
            templateRows += (building.receiptTemplate?.elements ?? []).map { templateRow($0, "building", building.id) }
        }
        files["receipt_templates.csv"] = csv(templateRows)
        files["rooms.csv"] = csv([["id", "building_id", "number", "rent", "custom_water_rate", "custom_electricity_rate", "occupied", "deposit_amount", "deposit_status", "deposit_collected_date", "deposit_refunded_date", "custom_water_meter_max", "custom_electricity_meter_max"]] + appData.rooms.map {
            [$0.id, $0.buildingId, $0.number, $0.rent, $0.customWaterRate ?? "", $0.customElectricityRate ?? "", String($0.occupied), $0.depositAmount, $0.depositStatus.rawValue, $0.depositCollectedDate ?? "", $0.depositRefundedDate ?? "", $0.customWaterMeterMax ?? "", $0.customElectricityMeterMax ?? ""]
        })
        files["bills.csv"] = csv([["id", "building_id", "room_id", "room_number", "month", "created_date", "previous_water", "current_water", "water_rate", "water_amount", "previous_electricity", "current_electricity", "electricity_rate", "electricity_amount", "rent", "total", "paid", "paid_date", "water_usage", "electricity_usage", "rent_only"]] + appData.bills.map {
            [$0.id, $0.buildingId, $0.roomId, $0.roomNumber, $0.month, $0.createdDate, $0.previousWater, $0.currentWater, $0.waterRate, $0.waterAmount, $0.previousElectricity, $0.currentElectricity, $0.electricityRate, $0.electricityAmount, $0.rent, $0.total, String($0.paid), $0.paidDate ?? "", $0.waterUsage, $0.electricityUsage, String($0.rentOnly)]
        })
        var chargeRows = [["bill_id", "item_index", "name", "amount"]]
        for bill in appData.bills {
            chargeRows += bill.customCharges.enumerated().map { [bill.id, String($0.offset), $0.element.name, $0.element.amount] }
        }
        files["bill_charges.csv"] = csv(chargeRows)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("房租数据备份_\(Date.isoDayFormatter.string(from: Date())).zip")
        try ZipContainer.write(files, to: url)
        return url
    }

    static func importArchive(from url: URL) throws -> AppData {
        let secured = url.startAccessingSecurityScopedResource()
        defer { if secured { url.stopAccessingSecurityScopedResource() } }
        let files = try ZipContainer.read(from: url)
        func table(_ name: String) throws -> CSVTable {
            guard let bytes = files[name], let text = String(data: bytes, encoding: .utf8) else { throw BackupError.message("备份缺少 \(name)") }
            return try CSVTable(text.replacingOccurrences(of: "\u{FEFF}", with: ""))
        }
        let manifest = try table("manifest.csv")
        guard let manifestRecord = manifest.records.first,
              manifestRecord.optional("format") == "rent-receipt" else {
            throw BackupError.message("备份格式不受支持")
        }
        let version = Int(manifestRecord.optional("version") ?? "") ?? 0
        guard (1...8).contains(version) else { throw BackupError.message("备份版本不受支持") }
        if version == 1 { return try importVersionOne(files) }

        let buildingTable = try table("buildings.csv")
        var buildings = try buildingTable.records.map { row in
            Building(id: try row.required("id"), name: try row.required("name"), settings: PricingSettings(
                defaultWaterRate: try row.required("default_water_rate"),
                defaultElectricityRate: try row.required("default_electricity_rate"),
                defaultWaterMeterMax: row.optional("default_water_meter_max"),
                defaultElectricityMeterMax: row.optional("default_electricity_meter_max") ?? "10000"))
        }
        guard !buildings.isEmpty else { throw BackupError.message("备份中没有楼栋") }
        let buildingIDs = Set(buildings.map(\.id))

        let roomTable = try table("rooms.csv")
        let rooms = try roomTable.records.map { row in
            let buildingID = try row.required("building_id")
            guard buildingIDs.contains(buildingID) else { throw BackupError.message("房间引用了不存在的楼栋") }
            return Room(id: try row.required("id"), number: try row.required("number"), rent: try row.required("rent"),
                        customWaterRate: row.optional("custom_water_rate"), customElectricityRate: row.optional("custom_electricity_rate"),
                        buildingId: buildingID, occupied: row.bool("occupied"), depositAmount: row.optional("deposit_amount") ?? "0",
                        depositStatus: DepositStatus(rawValue: row.optional("deposit_status") ?? "NOT_COLLECTED") ?? .notCollected,
                        depositCollectedDate: row.optional("deposit_collected_date"), depositRefundedDate: row.optional("deposit_refunded_date"),
                        customWaterMeterMax: row.optional("custom_water_meter_max"), customElectricityMeterMax: row.optional("custom_electricity_meter_max"))
        }

        let billTable = try table("bills.csv")
        var bills = try billTable.records.map { row in
            Bill(id: try row.required("id"), buildingId: try row.required("building_id"), roomId: try row.required("room_id"),
                 roomNumber: try row.required("room_number"), month: try row.required("month"), createdDate: try row.required("created_date"),
                 previousWater: try row.required("previous_water"), currentWater: try row.required("current_water"), waterRate: try row.required("water_rate"),
                 waterAmount: try row.required("water_amount"), previousElectricity: try row.required("previous_electricity"),
                 currentElectricity: try row.required("current_electricity"), electricityRate: try row.required("electricity_rate"),
                 electricityAmount: try row.required("electricity_amount"), rent: try row.required("rent"), total: try row.required("total"),
                 rentOnly: row.bool("rent_only"), paid: row.bool("paid"), paidDate: row.optional("paid_date"),
                 waterUsage: row.optional("water_usage") ?? "", electricityUsage: row.optional("electricity_usage") ?? "")
        }
        if let chargeData = files["bill_charges.csv"], let chargeText = String(data: chargeData, encoding: .utf8) {
            let chargeTable = try CSVTable(chargeText)
            let grouped = Dictionary(grouping: chargeTable.records, by: { $0.optional("bill_id") ?? "" })
            for index in bills.indices {
                bills[index].customCharges = try (grouped[bills[index].id] ?? []).sorted {
                    Int($0.optional("item_index") ?? "0") ?? 0 < Int($1.optional("item_index") ?? "0") ?? 0
                }.map { CustomCharge(name: try $0.required("name"), amount: try $0.required("amount")) }
            }
        }

        var globalTemplate = ReceiptTemplate()
        if let templateData = files["receipt_templates.csv"], let templateText = String(data: templateData, encoding: .utf8) {
            let templateTable = try CSVTable(templateText)
            func elements(scope: String, buildingID: String = "") throws -> [ReceiptTextElement] {
                try templateTable.records.filter { $0.optional("scope") == scope && (scope != "building" || $0.optional("building_id") == buildingID) }.map { row in
                    ReceiptTextElement(id: try row.required("id"), content: row.optional("content") ?? "", x: Double(try row.required("x")) ?? 0,
                                       y: Double(try row.required("y")) ?? 0, fontSize: Double(try row.required("font_size")) ?? 60,
                                       centered: row.bool("centered"), color: row.optional("color") ?? "body")
                }
            }
            let global = try elements(scope: "global")
            if !global.isEmpty { globalTemplate = ReceiptTemplate(elements: global) }
            for index in buildings.indices {
                let own = try elements(scope: "building", buildingID: buildings[index].id)
                if !own.isEmpty { buildings[index].receiptTemplate = ReceiptTemplate(elements: own) }
            }
        }
        return AppData(buildings: buildings, rooms: rooms, bills: bills, receiptTemplate: globalTemplate)
    }

    private static func importVersionOne(_ files: [String: Data]) throws -> AppData {
        guard let settingsData = files["settings.csv"], let settingsText = String(data: settingsData, encoding: .utf8),
              let roomData = files["rooms.csv"], let roomText = String(data: roomData, encoding: .utf8),
              let billData = files["bills.csv"], let billText = String(data: billData, encoding: .utf8) else {
            throw BackupError.message("旧版备份文件不完整")
        }
        let settingsTable = try CSVTable(settingsText)
        let settings = Dictionary(uniqueKeysWithValues: settingsTable.rows.dropFirst().compactMap { row in row.count >= 2 ? (row[0], row[1]) : nil })
        let building = Building(id: defaultBuildingID, name: "默认楼栋", settings: PricingSettings(defaultWaterRate: settings["default_water_rate"] ?? "5", defaultElectricityRate: settings["default_electricity_rate"] ?? "1.3"))
        let rooms = try CSVTable(roomText).records.map { row in
            Room(id: try row.required("id"), number: try row.required("number"), rent: try row.required("rent"), customWaterRate: row.optional("custom_water_rate"), customElectricityRate: row.optional("custom_electricity_rate"), buildingId: defaultBuildingID)
        }
        let bills = try CSVTable(billText).records.map { row in
            Bill(id: try row.required("id"), buildingId: defaultBuildingID, roomId: try row.required("room_id"), roomNumber: try row.required("room_number"), month: try row.required("month"), createdDate: try row.required("created_date"), previousWater: try row.required("previous_water"), currentWater: try row.required("current_water"), waterRate: try row.required("water_rate"), waterAmount: try row.required("water_amount"), previousElectricity: try row.required("previous_electricity"), currentElectricity: try row.required("current_electricity"), electricityRate: try row.required("electricity_rate"), electricityAmount: try row.required("electricity_amount"), rent: try row.required("rent"), total: try row.required("total"))
        }
        return AppData(buildings: [building], rooms: rooms, bills: bills)
    }

    private static func templateRow(_ value: ReceiptTextElement, _ scope: String, _ building: String) -> [String] {
        [scope, building, value.id, value.content, String(value.x), String(value.y), String(value.fontSize), String(value.centered), value.color]
    }
    private static func csv(_ rows: [[String]]) -> Data {
        let text = rows.map { $0.map { value in "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }.joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
        return Data(text.utf8)
    }
}

private struct CSVTable {
    let rows: [[String]]
    let headers: [String]
    var records: [CSVRecord] { rows.dropFirst().filter { $0.contains(where: { !$0.isEmpty }) }.map { CSVRecord(headers: headers, values: $0) } }
    init(_ text: String) throws {
        var result = [[String]](), row = [String](), field = "", quoted = false
        // Swift treats CRLF as a single Character. Normalize it first so line
        // boundaries are recognized both in Android exports and our own files.
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let chars = Array(normalized); var index = 0
        while index < chars.count {
            let char = chars[index]
            if quoted {
                if char == "\"" {
                    if index + 1 < chars.count && chars[index + 1] == "\"" { field.append("\""); index += 1 }
                    else { quoted = false }
                } else { field.append(char) }
            } else if char == "\"" { quoted = true }
            else if char == "," { row.append(field); field = "" }
            else if char == "\n" { row.append(field.trimmingCharacters(in: CharacterSet(charactersIn: "\r"))); result.append(row); row = []; field = "" }
            else { field.append(char) }
            index += 1
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); result.append(row) }
        guard let header = result.first else { throw BackupError.message("CSV 文件为空") }
        rows = result; headers = header
    }
}

private struct CSVRecord {
    let values: [String: String]
    init(headers: [String], values: [String]) { self.values = Dictionary(uniqueKeysWithValues: headers.enumerated().map { ($0.element, values[safe: $0.offset] ?? "") }) }
    func required(_ key: String) throws -> String {
        guard let value = values[key], !value.isEmpty else { throw BackupError.message("备份缺少字段：\(key)") }
        return value
    }
    func optional(_ key: String) -> String? { values[key].flatMap { $0.isEmpty ? nil : $0 } }
    func bool(_ key: String) -> Bool { optional(key)?.lowercased() == "true" }
}

private enum ZipContainer {
    static func write(_ files: [String: Data], to url: URL) throws {
        var output = Data(), central = Data()
        for (name, bytes) in files.sorted(by: { $0.key < $1.key }) {
            let nameData = Data(name.utf8), offset = UInt32(output.count), checksum = crc(bytes)
            output.appendLE(UInt32(0x04034b50)); output.appendLE(UInt16(20)); output.appendLE(UInt16(0x0800)); output.appendLE(UInt16(0)); output.appendLE(UInt16(0)); output.appendLE(UInt16(0)); output.appendLE(checksum); output.appendLE(UInt32(bytes.count)); output.appendLE(UInt32(bytes.count)); output.appendLE(UInt16(nameData.count)); output.appendLE(UInt16(0)); output.append(nameData); output.append(bytes)
            central.appendLE(UInt32(0x02014b50)); central.appendLE(UInt16(20)); central.appendLE(UInt16(20)); central.appendLE(UInt16(0x0800)); central.appendLE(UInt16(0)); central.appendLE(UInt16(0)); central.appendLE(UInt16(0)); central.appendLE(checksum); central.appendLE(UInt32(bytes.count)); central.appendLE(UInt32(bytes.count)); central.appendLE(UInt16(nameData.count)); central.appendLE(UInt16(0)); central.appendLE(UInt16(0)); central.appendLE(UInt16(0)); central.appendLE(UInt16(0)); central.appendLE(UInt32(0)); central.appendLE(offset); central.append(nameData)
        }
        let centralOffset = UInt32(output.count); output.append(central)
        output.appendLE(UInt32(0x06054b50)); output.appendLE(UInt16(0)); output.appendLE(UInt16(0)); output.appendLE(UInt16(files.count)); output.appendLE(UInt16(files.count)); output.appendLE(UInt32(central.count)); output.appendLE(centralOffset); output.appendLE(UInt16(0))
        try output.write(to: url, options: .atomic)
    }

    static func read(from url: URL) throws -> [String: Data] {
        let bytes = try Data(contentsOf: url)
        guard let end = bytes.lastIndex(ofSignature: 0x06054b50), let count: UInt16 = bytes.le(at: end + 10), let centralOffset: UInt32 = bytes.le(at: end + 16) else { throw BackupError.message("ZIP 文件损坏") }
        var cursor = Int(centralOffset), result: [String: Data] = [:]
        for _ in 0..<count {
            guard bytes.le(at: cursor) as UInt32? == 0x02014b50,
                  let method: UInt16 = bytes.le(at: cursor + 10), let compressed: UInt32 = bytes.le(at: cursor + 20),
                  let uncompressed: UInt32 = bytes.le(at: cursor + 24), let nameLength: UInt16 = bytes.le(at: cursor + 28),
                  let extraLength: UInt16 = bytes.le(at: cursor + 30), let commentLength: UInt16 = bytes.le(at: cursor + 32),
                  let localOffset: UInt32 = bytes.le(at: cursor + 42) else { throw BackupError.message("ZIP 目录损坏") }
            let nameStart = cursor + 46, nameEnd = nameStart + Int(nameLength)
            guard nameEnd <= bytes.count, let name = String(data: bytes[nameStart..<nameEnd], encoding: .utf8),
                  let localNameLength: UInt16 = bytes.le(at: Int(localOffset) + 26), let localExtraLength: UInt16 = bytes.le(at: Int(localOffset) + 28) else { throw BackupError.message("ZIP 文件名损坏") }
            let dataStart = Int(localOffset) + 30 + Int(localNameLength) + Int(localExtraLength), dataEnd = dataStart + Int(compressed)
            guard dataEnd <= bytes.count else { throw BackupError.message("ZIP 条目超出范围") }
            let source = Data(bytes[dataStart..<dataEnd])
            if method == 0 { result[name] = source }
            else if method == 8 { result[name] = try inflateRaw(source, expected: Int(uncompressed)) }
            else { throw BackupError.message("ZIP 使用了不支持的压缩方式") }
            cursor = nameEnd + Int(extraLength) + Int(commentLength)
        }
        return result
    }

    private static func crc(_ data: Data) -> UInt32 { data.withUnsafeBytes { UInt32(zlib.crc32(0, $0.bindMemory(to: Bytef.self).baseAddress, uInt(data.count))) } }
    private static func inflateRaw(_ data: Data, expected: Int) throws -> Data {
        var output = Data(count: expected), stream = z_stream()
        let status: Int32 = data.withUnsafeBytes { input in output.withUnsafeMutableBytes { destination in
            stream.next_in = UnsafeMutablePointer(mutating: input.bindMemory(to: Bytef.self).baseAddress)
            stream.avail_in = uInt(data.count); stream.next_out = destination.bindMemory(to: Bytef.self).baseAddress; stream.avail_out = uInt(expected)
            guard inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else { return Z_STREAM_ERROR }
            defer { inflateEnd(&stream) }
            return inflate(&stream, Z_FINISH)
        } }
        guard status == Z_STREAM_END else { throw BackupError.message("ZIP 解压失败") }
        return output
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}
private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) { var little = value.littleEndian; Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) } }
    func le<T: FixedWidthInteger>(at index: Int) -> T? {
        guard index >= 0, index + MemoryLayout<T>.size <= count else { return nil }
        return self[index..<(index + MemoryLayout<T>.size)].withUnsafeBytes { T(littleEndian: $0.loadUnaligned(as: T.self)) }
    }
    func lastIndex(ofSignature signature: UInt32) -> Int? {
        guard count >= 4 else { return nil }
        for index in stride(from: count - 4, through: Swift.max(0, count - 65_557), by: -1) { if (le(at: index) as UInt32?) == signature { return index } }
        return nil
    }
}
