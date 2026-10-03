import SwiftUI
import UIKit

enum ReceiptRenderer {
    static let width: CGFloat = 3508
    static let baseHeight: CGFloat = 1970
    static let customRowHeight: CGFloat = 240
    private static let detailLabelSize: CGFloat = 66
    private static let detailValueSize: CGFloat = 136

    static func image(for bill: Bill, buildingName: String, template: ReceiptTemplate = ReceiptTemplate()) -> UIImage {
        let height = baseHeight + CGFloat(bill.customCharges.count) * customRowHeight
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { renderer in
            draw(bill, buildingName: buildingName, template: template, in: renderer.cgContext)
        }
    }

    static func writeTemporaryPNG(for bill: Bill, buildingName: String, template: ReceiptTemplate = ReceiptTemplate()) throws -> URL {
        try writeTemporaryPNG(image(for: bill, buildingName: buildingName, template: template), for: bill)
    }

    static func writeTemporaryPNG(_ image: UIImage, for bill: Bill) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(bill.month)-\(bill.roomNumber)房-房租单.png")
        guard let data = image.pngData() else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func draw(_ bill: Bill, buildingName: String, template: ReceiptTemplate, in context: CGContext) {
        let customOffset = CGFloat(bill.customCharges.count) * customRowHeight
        UIColor(red: 1, green: 0.988, blue: 0.957, alpha: 1).setFill()
        context.fill(CGRect(x: 0, y: 0, width: width, height: baseHeight + customOffset))
        context.saveGState(); context.translateBy(x: 0, y: 70)

        let ink = UIColor(red: 0.145, green: 0.145, blue: 0.145, alpha: 1)
        let blue = UIColor(red: 0.071, green: 0.286, blue: 0.592, alpha: 1)
        let red = UIColor(red: 0.604, green: 0.094, blue: 0.141, alpha: 1)
        let left: CGFloat = 95, right = width - 95, top: CGFloat = 285
        let detailsBottom: CGFloat = 1400 + customOffset, bottom: CGFloat = 1800 + customOffset
        let columns: [CGFloat] = [left, 620, 1100, 1580, 2060, right]
        var rows: [CGFloat] = [500, 800, 1100, 1400]
        for index in bill.customCharges.indices { rows.append(1400 + CGFloat(index + 1) * customRowHeight) }
        rows.append(bottom)
        context.setStrokeColor(ink.cgColor); context.setLineWidth(5)
        context.stroke(CGRect(x: left, y: top, width: right - left, height: bottom - top))
        for x in columns.dropFirst().dropLast() { context.move(to: CGPoint(x: x, y: top)); context.addLine(to: CGPoint(x: x, y: detailsBottom)); context.strokePath() }
        for y in rows { context.move(to: CGPoint(x: left, y: y)); context.addLine(to: CGPoint(x: right, y: y)); context.strokePath() }

        for (index, charge) in bill.customCharges.enumerated() {
            let rowTop = 1400 + CGFloat(index) * customRowHeight
            centered(charge.name, rect: CGRect(x: left, y: rowTop, width: 525, height: customRowHeight), size: detailLabelSize, color: ink, numeric: false)
            centered(charge.amount, rect: CGRect(x: 2060, y: rowTop, width: right - 2060, height: customRowHeight), size: detailValueSize, color: blue, numeric: true)
        }

        for element in template.elements {
            if element.id == "date" {
                drawStyledDate(bill, element: element, ink: ink, blue: blue, left: left, right: right)
                continue
            }
            if element.id == "room" {
                drawRoomLine(bill.roomNumber, buildingName: buildingName, element: element, ink: ink, blue: blue)
                continue
            }
            if element.id == "roomSuffix" { continue }
            let value = resolve(element.content, bill: bill, buildingName: buildingName)
            let color = element.color == "blue" ? blue : (element.color == "red" ? red : ink)
            let bounds = cellBounds(element.id, customOffset: customOffset)
            let maxWidth = (bounds?.width ?? fallbackWidth(element.id)) - 40
            var size = detailLabelIDs.contains(element.id) ? detailLabelSize : (detailValueIDs.contains(element.id) ? detailValueSize : CGFloat(element.fontSize))
            var attributes = textAttributes(size: size, color: color, id: element.id)
            while (value as NSString).size(withAttributes: attributes).width > maxWidth && size > 34 {
                size -= 2; attributes = textAttributes(size: size, color: color, id: element.id)
            }
            let measured = (value as NSString).size(withAttributes: attributes)
            let x: CGFloat
            let y: CGFloat
            if let bounds {
                x = bounds.midX - measured.width / 2
                y = bounds.midY - measured.height / 2
            } else {
                x = element.centered ? CGFloat(element.x) - measured.width / 2 : CGFloat(element.x)
                y = CGFloat(element.y) - measured.height
            }
            (value as NSString).draw(at: CGPoint(x: max(left, min(x, right - measured.width)), y: y), withAttributes: attributes)
        }
        context.restoreGState()
    }

    private static func drawRoomLine(
        _ roomNumber: String,
        buildingName: String,
        element: ReceiptTextElement,
        ink: UIColor,
        blue: UIColor
    ) {
        let numberSize = CGFloat(element.fontSize)
        let result = NSMutableAttributedString()
        result.append(NSAttributedString(
            string: roomNumber,
            attributes: [.font: numberFont(numberSize), .foregroundColor: blue]
        ))
        let suffixFont = UIFont(name: "STSongti-SC-Bold", size: 66) ?? .systemFont(ofSize: 66, weight: .bold)
        result.append(NSAttributedString(
            string: "号",
            attributes: [.font: suffixFont, .foregroundColor: ink]
        ))
        let buildingFont = UIFont(name: "STSongti-SC-Bold", size: 92) ?? .systemFont(ofSize: 92, weight: .bold)
        result.append(NSAttributedString(
            string: "（\(buildingName)）",
            attributes: [.font: buildingFont, .foregroundColor: blue]
        ))
        let maxWidth: CGFloat = 1500
        if result.size().width > maxWidth {
            let scale = maxWidth / result.size().width
            result.enumerateAttribute(.font, in: NSRange(location: 0, length: result.length)) { value, range, _ in
                guard let font = value as? UIFont else { return }
                result.addAttribute(.font, value: font.withSize(font.pointSize * scale), range: range)
            }
        }
        result.draw(at: CGPoint(x: CGFloat(element.x), y: CGFloat(element.y) - numberFont(numberSize).ascender))
    }

    private static func textAttributes(size: CGFloat, color: UIColor, id: String) -> [NSAttributedString.Key: Any] {
        let font: UIFont
        if id == "totalUpper" {
            font = UIFont(name: "FZFangSong-Z02S", size: size) ?? UIFont(name: "STSongti-SC-Bold", size: size) ?? .systemFont(ofSize: size, weight: .bold)
        } else if isNumeric(id) {
            font = numberFont(size)
        } else {
            font = UIFont(name: "STSongti-SC-Bold", size: size) ?? .systemFont(ofSize: size, weight: .bold)
        }
        return [.font: font, .foregroundColor: color]
    }

    private static func numberFont(_ size: CGFloat) -> UIFont {
        UIFont(name: "TimesNewRomanPS-BoldMT", size: size) ?? UIFont.monospacedDigitSystemFont(ofSize: size, weight: .bold)
    }

    private static func centered(_ value: String, rect: CGRect, size: CGFloat, color: UIColor, numeric: Bool) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: numeric ? numberFont(size) : (UIFont(name: "STSongti-SC-Bold", size: size) ?? .systemFont(ofSize: size, weight: .bold)),
            .foregroundColor: color
        ]
        let measured = (value as NSString).size(withAttributes: attributes)
        (value as NSString).draw(at: CGPoint(x: rect.midX - measured.width / 2, y: rect.midY - measured.height / 2), withAttributes: attributes)
    }

    private static func drawStyledDate(_ bill: Bill, element: ReceiptTextElement, ink: UIColor, blue: UIColor, left: CGFloat, right: CGFloat) {
        let pieces = bill.month.split(separator: "-")
        let year = Int(pieces.first ?? "") ?? Calendar.current.component(.year, from: Date())
        let month = pieces.count > 1 ? (Int(pieces[1]) ?? 1) : 1
        let size = CGFloat(element.fontSize)
        let result = NSMutableAttributedString()
        func append(_ value: String, font: UIFont, color: UIColor) {
            result.append(NSAttributedString(string: value, attributes: [.font: font, .foregroundColor: color]))
        }
        let labelFont = UIFont(name: "STSongti-SC-Bold", size: size) ?? .systemFont(ofSize: size, weight: .bold)
        append(String(year), font: numberFont(size), color: blue)
        append(" 年 ", font: labelFont, color: ink)
        append(String(month), font: numberFont(size), color: blue)
        append(" 月 ", font: labelFont, color: ink)
        append("1", font: numberFont(size), color: blue)
        append(" 日", font: labelFont, color: ink)
        if result.size().width > 850 {
            let scale = 850 / result.size().width
            result.enumerateAttribute(.font, in: NSRange(location: 0, length: result.length)) { value, range, _ in
                guard let font = value as? UIFont else { return }
                result.addAttribute(.font, value: font.withSize(font.pointSize * scale), range: range)
            }
        }
        let measured = result.size()
        let x = max(left, min(CGFloat(element.x), right - measured.width))
        let baselineFont = numberFont(size)
        result.draw(at: CGPoint(x: x, y: CGFloat(element.y) - baselineFont.ascender))
    }

    private static func resolve(_ source: String, bill: Bill, buildingName: String) -> String {
        let replacements = [
            "{room}": "\(bill.roomNumber)号（\(buildingName)）", "{receiptNo}": bill.month.replacingOccurrences(of: "-", with: "") + bill.roomNumber,
            "{date}": bill.month.replacingOccurrences(of: "-", with: " 年 ") + " 月 1 日",
            "{currentWater}": bill.currentWater, "{previousWater}": bill.previousWater,
            "{waterUsage}": bill.waterUsage.isEmpty ? usage(bill.currentWater, bill.previousWater) : bill.waterUsage,
            "{waterRate}": bill.waterRate, "{waterAmount}": bill.waterAmount,
            "{currentElectricity}": bill.currentElectricity, "{previousElectricity}": bill.previousElectricity,
            "{electricityUsage}": bill.electricityUsage.isEmpty ? usage(bill.currentElectricity, bill.previousElectricity) : bill.electricityUsage,
            "{electricityRate}": bill.electricityRate, "{electricityAmount}": bill.electricityAmount,
            "{rent}": bill.rent, "{totalUpper}": rmbUpper(Decimal(string: bill.total) ?? 0), "{total}": bill.total
        ]
        return replacements.reduce(source) { $0.replacingOccurrences(of: $1.key, with: $1.value) }
    }

    private static func usage(_ current: String, _ previous: String) -> String {
        BillCalculator.text((Decimal(string: current) ?? 0) - (Decimal(string: previous) ?? 0))
    }

    private static func cellBounds(_ id: String, customOffset: CGFloat) -> CGRect? {
        let left: CGFloat = 95, right = width - 95
        let row: (CGFloat, CGFloat)? = {
            if id.hasPrefix("head") { return (285, 500) }
            if id.hasPrefix("water") { return (500, 800) }
            if id.hasPrefix("electric") { return (800, 1100) }
            if id.hasPrefix("rent") { return (1100, 1400) }
            if id.hasPrefix("total") { return (1400 + customOffset, 1800 + customOffset) }
            return nil
        }()
        guard let row else { return nil }
        if id == "totalLabel" { return CGRect(x: left, y: row.0, width: 525, height: row.1 - row.0) }
        if id == "totalUpper" { return CGRect(x: 620, y: row.0, width: 1820, height: row.1 - row.0) }
        if id == "total" { return CGRect(x: 2440, y: row.0, width: right - 2440, height: row.1 - row.0) }
        let pair: (CGFloat, CGFloat)
        if id.hasSuffix("Label") { pair = (left, 620) }
        else if id.hasSuffix("Current") { pair = (620, 1100) }
        else if id.hasSuffix("Previous") { pair = (1100, 1580) }
        else if id.hasSuffix("Usage") { pair = (1580, 2060) }
        else if id.hasSuffix("Amount") { pair = (2060, right) }
        else { return nil }
        return CGRect(x: pair.0, y: row.0, width: pair.1 - pair.0, height: row.1 - row.0)
    }

    private static func fallbackWidth(_ id: String) -> CGFloat {
        switch id { case "title": 2500; case "room": 1500; case "receiptNo": 620; case "date": 850; default: 1000 }
    }
    private static func isNumeric(_ id: String) -> Bool {
        ["room", "receiptNo", "waterCurrent", "waterPrevious", "waterUsage", "waterAmount", "electricCurrent", "electricPrevious", "electricUsage", "electricAmount", "rentUsage", "rentAmount", "total"].contains(id)
    }
    private static let detailLabelIDs: Set<String> = ["headItem", "headCurrent", "headPrevious", "headUsage", "headAmount", "waterLabel", "electricLabel", "rentLabel"]
    private static let detailValueIDs: Set<String> = ["waterCurrent", "waterPrevious", "waterUsage", "waterAmount", "electricCurrent", "electricPrevious", "electricUsage", "electricAmount", "rentUsage", "rentAmount"]

    static func rmbUpper(_ amount: Decimal) -> String {
        let digits = Array("零壹贰叁肆伍陆柒捌玖"), units = ["", "拾", "佰", "仟"], sections = ["", "万", "亿", "兆"]
        let integer = NSDecimalNumber(decimal: BillCalculator.rounded(amount)).int64Value
        if integer == 0 { return "零元整" }
        var number = integer, sectionIndex = 0, result = "", pendingZero = false
        while number > 0 {
            let section = Int(number % 10000)
            if section == 0 { pendingZero = !result.isEmpty }
            else {
                var value = section, unitIndex = 0, sectionText = "", zero = false
                while value > 0 {
                    let digit = value % 10
                    if digit == 0 { zero = !sectionText.isEmpty }
                    else {
                        sectionText = (zero ? "零" : "") + String(digits[digit]) + units[unitIndex] + sectionText
                        zero = false
                    }
                    value /= 10; unitIndex += 1
                }
                result = ((pendingZero || (section < 1000 && !result.isEmpty)) ? "零" : "") + sectionText + sections[sectionIndex] + result
                pendingZero = false
            }
            number /= 10000; sectionIndex += 1
        }
        return result + "元整"
    }
}

struct ReceiptPreviewView: View {
    @EnvironmentObject private var store: AppStore
    let bill: Bill
    @State private var image: UIImage?
    @State private var shareURL: URL?
    @State private var error: String?
    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 16) {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(radius: 10, y: 4)
                            .accessibilityLabel("\(bill.month) \(bill.roomNumber)房收据预览")
                    } else {
                        ProgressView("正在生成收据…").padding(.vertical, 80)
                    }
                    if let error { Text(error).foregroundStyle(.red) }
                }.padding().frame(maxWidth: 900).frame(maxWidth: .infinity)
            }
            .softTitleScrollEdge()
        }
        .navigationTitle("\(bill.roomNumber) 房收据")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let shareURL {
                    ShareLink(item: shareURL) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("分享收据")
                } else {
                    ProgressView().accessibilityLabel("正在准备分享")
                }
            }
        }
        .task(id: bill.id) {
            do {
                let buildingName = store.data.buildings.first { $0.id == bill.buildingId }?.name ?? "楼栋"
                let result = try await Task.detached(priority: .userInitiated) {
                    let rendered = ReceiptRenderer.image(for: bill, buildingName: buildingName)
                    return (rendered, try ReceiptRenderer.writeTemporaryPNG(rendered, for: bill))
                }.value
                image = result.0
                shareURL = result.1
            } catch {
                self.error = "生成失败：\(error.localizedDescription)"
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
