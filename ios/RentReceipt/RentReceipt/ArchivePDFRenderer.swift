import Foundation
import UIKit

enum ArchivePDFRenderer {
    private static let page = CGSize(width: 842, height: 595)
    private static let margin: CGFloat = 30
    private static let roomsPerPage = 15
    private static let monthsPerPage = 3

    static func write(building: Building, rooms: [Room], bills: [Bill], start: MonthValue, end: MonthValue) throws -> URL {
        guard start.id <= end.id else { throw BackupError.message("结束月份不能早于开始月份") }
        var months = [MonthValue](), cursor = start
        while cursor.id <= end.id { months.append(cursor); cursor = cursor.next }
        let roomPages = rooms.isEmpty ? [[]] : stride(from: 0, to: rooms.count, by: roomsPerPage).map { Array(rooms[$0..<min($0 + roomsPerPage, rooms.count)]) }
        let monthPages = stride(from: 0, to: months.count, by: monthsPerPage).map { Array(months[$0..<min($0 + monthsPerPage, months.count)]) }
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: page))
        let data = renderer.pdfData { context in
            var pageNumber = 0
            for monthGroup in monthPages {
                for roomGroup in roomPages {
                    pageNumber += 1; context.beginPage()
                    draw(context.cgContext, building: building, rooms: roomGroup, bills: bills, months: monthGroup,
                         range: "\(start.id) 至 \(end.id)", pageNumber: pageNumber, pageCount: roomPages.count * monthPages.count)
                }
            }
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(building.name)_\(start.id)_至_\(end.id)_房屋留档.pdf")
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func draw(_ context: CGContext, building: Building, rooms: [Room], bills: [Bill], months: [MonthValue], range: String, pageNumber: Int, pageCount: Int) {
        UIColor.white.setFill(); context.fill(CGRect(origin: .zero, size: page))
        let title = attributes(17, .bold), body = attributes(9, .regular), small = attributes(8, .regular)
        let numberTitle = numberAttributes(17), numberBody = numberAttributes(9), numberSmall = numberAttributes(8)
        drawMixed("\(building.name) 房屋水电留档  \(range)", at: CGPoint(x: margin, y: 18), text: title, number: numberTitle)
        let top: CGFloat = 52, header: CGFloat = 44, rowHeight: CGFloat = 28
        let widths: [CGFloat] = [66, 46, 52, 72]
        let fixed = widths.reduce(0, +), tableWidth = page.width - margin * 2
        let monthWidth = (tableWidth - fixed) / CGFloat(max(months.count, 1))
        var xs = [margin]
        widths.forEach { xs.append(xs.last! + $0) }
        months.forEach { _ in xs.append(xs.last! + monthWidth) }
        let bottom = top + header + CGFloat(rooms.count + 1) * rowHeight
        context.setStrokeColor(UIColor.darkGray.cgColor); context.setLineWidth(0.8)
        for x in xs { line(context, x, top, x, bottom) }
        line(context, margin, top, margin + tableWidth, top); line(context, margin, top + header, margin + tableWidth, top + header)
        for index in 0...rooms.count { let y = top + header + CGFloat(index + 1) * rowHeight; line(context, margin, y, margin + tableWidth, y) }
        for (index, label) in ["房号", "出租", "租金", "押金"].enumerated() { center(label, xs[index], xs[index + 1], top + 15, top + header, body) }
        for (index, month) in months.enumerated() {
            let left = xs[index + 4], right = xs[index + 5], one = left + (right-left)/3, two = left + (right-left)*2/3
            center("\(month.year).\(month.month)", left, right, top, top + 20, numberBody); line(context, left, top + 20, right, top + 20)
            line(context, one, top + 20, one, bottom); line(context, two, top + 20, two, bottom)
            center("水(m³)", left, one, top + 20, top + header, body); center("电(度)", one, two, top + 20, top + header, body); center("总额(元)", two, right, top + 20, top + header, body)
        }
        let billMap = Dictionary(uniqueKeysWithValues: bills.map { ("\($0.roomId)|\($0.month)", $0) })
        for (row, room) in rooms.enumerated() {
            let rowTop = top + header + CGFloat(row) * rowHeight
            center(room.number, xs[0], xs[1], rowTop, rowTop + rowHeight, numberBody)
            center(room.occupied ? "已租" : "空置", xs[1], xs[2], rowTop, rowTop + rowHeight, body)
            center(whole(room.rent), xs[2], xs[3], rowTop, rowTop + rowHeight, numberBody)
            centerMixed("\(whole(room.depositAmount))/\(room.depositStatus.title)", xs[3], xs[4], rowTop, rowTop + rowHeight, text: body, number: numberBody)
            for (index, month) in months.enumerated() {
                let bill = billMap["\(room.id)|\(month.id)"], left = xs[index+4], right = xs[index+5], one = left+(right-left)/3, two = left+(right-left)*2/3
                center(bill.map { resolvedUsage($0.waterUsage, current: $0.currentWater, previous: $0.previousWater) } ?? "-", left, one, rowTop, rowTop+rowHeight, numberBody)
                center(bill.map { resolvedUsage($0.electricityUsage, current: $0.currentElectricity, previous: $0.previousElectricity) } ?? "-", one, two, rowTop, rowTop+rowHeight, numberBody)
                center(bill?.total ?? "-", two, right, rowTop, rowTop+rowHeight, numberBody)
            }
        }
        let summaryTop = top + header + CGFloat(rooms.count) * rowHeight
        center("月汇总", xs[0], xs[1], summaryTop, summaryTop+rowHeight, body); center("费用", xs[1], xs[4], summaryTop, summaryTop+rowHeight, body)
        for (index, month) in months.enumerated() {
            let values = bills.filter { $0.month == month.id }, left = xs[index+4], right = xs[index+5], one = left+(right-left)/3, two = left+(right-left)*2/3
            center(sum(values.map(\.waterAmount)), left, one, summaryTop, summaryTop+rowHeight, numberBody)
            center(sum(values.map(\.electricityAmount)), one, two, summaryTop, summaryTop+rowHeight, numberBody)
            center(sum(values.map(\.total)), two, right, summaryTop, summaryTop+rowHeight, numberBody)
        }
        ("水量、电量为当月实际用量；总额为每房当月应收；月汇总行为全楼费用。" as NSString).draw(at: CGPoint(x: margin, y: page.height - 28), withAttributes: small)
        let pageText = "第 \(pageNumber) / \(pageCount) 页"
        let pageSize = mixed(pageText, text: small, number: numberSmall).size()
        drawMixed(pageText, at: CGPoint(x: page.width - margin - pageSize.width, y: page.height - 28), text: small, number: numberSmall)
    }

    private static func attributes(_ size: CGFloat, _ weight: UIFont.Weight) -> [NSAttributedString.Key: Any] { [.font: UIFont.systemFont(ofSize: size, weight: weight), .foregroundColor: UIColor.label] }
    private static func numberAttributes(_ size: CGFloat) -> [NSAttributedString.Key: Any] { [.font: UIFont(name: "TimesNewRomanPS-BoldMT", size: size) ?? UIFont.monospacedDigitSystemFont(ofSize: size, weight: .bold), .foregroundColor: UIColor.label] }
    private static func line(_ c: CGContext, _ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) { c.move(to: CGPoint(x: x1, y: y1)); c.addLine(to: CGPoint(x: x2, y: y2)); c.strokePath() }
    private static func center(_ value: String, _ left: CGFloat, _ right: CGFloat, _ top: CGFloat, _ bottom: CGFloat, _ attr: [NSAttributedString.Key: Any]) { let text = value as NSString, size = text.size(withAttributes: attr); text.draw(at: CGPoint(x: left+(right-left-size.width)/2, y: top+(bottom-top-size.height)/2), withAttributes: attr) }
    private static func sum(_ values: [String]) -> String { BillCalculator.text(values.reduce(Decimal.zero) { $0 + (Decimal(string: $1) ?? 0) }) }
    private static func whole(_ value: String) -> String { BillCalculator.text(Decimal(string: value) ?? 0) }
    private static func resolvedUsage(_ stored: String, current: String, previous: String) -> String {
        stored.nonEmpty ?? BillCalculator.text((Decimal(string: current) ?? 0) - (Decimal(string: previous) ?? 0))
    }
    private static func mixed(_ value: String, text: [NSAttributedString.Key: Any], number: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var buffer = "", usesNumber: Bool?
        func flush() {
            guard !buffer.isEmpty, let usesNumber else { return }
            result.append(NSAttributedString(string: buffer, attributes: usesNumber ? number : text)); buffer = ""
        }
        for character in value {
            let next = character.isASCII || character == "³"
            if usesNumber != nil && usesNumber != next { flush() }
            usesNumber = next; buffer.append(character)
        }
        flush(); return result
    }
    private static func drawMixed(_ value: String, at point: CGPoint, text: [NSAttributedString.Key: Any], number: [NSAttributedString.Key: Any]) {
        mixed(value, text: text, number: number).draw(at: point)
    }
    private static func centerMixed(_ value: String, _ left: CGFloat, _ right: CGFloat, _ top: CGFloat, _ bottom: CGFloat, text: [NSAttributedString.Key: Any], number: [NSAttributedString.Key: Any]) {
        let attributed = mixed(value, text: text, number: number), size = attributed.size()
        attributed.draw(at: CGPoint(x: left + (right - left - size.width) / 2, y: top + (bottom - top - size.height) / 2))
    }
}

private extension String { var nonEmpty: String? { isEmpty ? nil : self } }
