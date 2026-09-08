import SwiftUI
import UniformTypeIdentifiers

struct RoomsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var editingRoom: Room?
    @State private var addingRoom = false
    @State private var showingSettings = false
    @State private var editingBuilding: Building?
    @State private var addingBuilding = false
    @State private var exportDocument: ExportDocument?
    @State private var exportType: UTType = .data
    @State private var exportFilename = "导出文件"
    @State private var showingExporter = false
    @State private var exporting = false
    @State private var importing = false
    @State private var pendingRestore: AppData?
    @State private var message: String?
    @State private var pdfStart = MonthValue(year: Calendar.current.component(.year, from: Date()), month: 1)
    @State private var pdfEnd = MonthValue(year: Calendar.current.component(.year, from: Date()), month: 12)

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                LazyVStack(spacing: 14) {
                    AppCard {
                        VStack(alignment: .leading, spacing: 12) {
                            AdaptiveStack {
                                VStack(alignment: .leading) {
                                    Text(store.selectedBuilding.name).font(.title2.bold())
                                    Text("当前楼栋").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("改名") { editingBuilding = store.selectedBuilding }
                                Button("新增楼栋") { addingBuilding = true }
                            }
                        }
                    }

                    AppCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("房东留档 PDF", systemImage: "doc.richtext.fill").font(.headline)
                            Text("按当前楼栋导出；每行一个房间，各月份显示水、电用量。").font(.subheadline).foregroundStyle(.secondary)
                            MonthStepper(title: "开始", month: $pdfStart)
                            MonthStepper(title: "结束", month: $pdfEnd)
                            if exporting {
                                ProgressView("正在生成文件…")
                            } else {
                                Button("导出 PDF") { exportPDF() }.disabled(store.rooms().isEmpty || pdfStart.id > pdfEnd.id).prominentGlassButton()
                            }
                        }
                    }

                    AppCard {
                        AdaptiveStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("默认单价").font(.headline)
                                Text("水 ¥\(store.selectedBuilding.settings.defaultWaterRate) / 吨 · 电 ¥\(store.selectedBuilding.settings.defaultElectricityRate) / 度")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("修改") { showingSettings = true }
                        }
                    }

                    AppCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("完整备份与恢复", systemImage: "externaldrive.fill").font(.headline)
                            Text("备份包含全部楼栋、房间、设置和历史账单，可与 Android 版互换。")
                                .font(.subheadline).foregroundStyle(.secondary)
                            AdaptiveStack {
                                Button("导出 ZIP") { exportBackup() }.buttonStyle(.bordered)
                                Button("导入恢复") { importing = true }.buttonStyle(.bordered)
                            }
                            if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
                        }
                    }

                    AdaptiveStack {
                        Text("房间（\(store.rooms().count)）").font(.title2.bold())
                        Spacer()
                        Button { addingRoom = true } label: { Label("新增", systemImage: "plus") }.prominentGlassButton()
                    }

                    if store.rooms().isEmpty {
                        EmptyState(icon: "door.left.hand.open", title: "还没有房间", detail: "新增第一个房间后即可开始录入账单。")
                    }
                    ForEach(store.rooms()) { room in
                        Button { editingRoom = room } label: {
                            AppCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("\(room.number) 房").font(.headline)
                                        Text("\(room.occupied ? "已出租" : "空置") · 月租 ¥\(room.rent) · 押金 ¥\(room.depositAmount)（\(room.depositStatus.title)）")
                                            .font(.caption).foregroundStyle(.secondary)
                                        Text("水 ¥\(room.customWaterRate ?? store.selectedBuilding.settings.defaultWaterRate) · 电 ¥\(room.customElectricityRate ?? store.selectedBuilding.settings.defaultElectricityRate)")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary).accessibilityHidden(true)
                                }
                            }
                        }.buttonStyle(.plain)
                    }
                }
                .padding(16).padding(.bottom, 30)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .softTitleScrollEdge()
        }
        .navigationTitle("房间管理")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { BuildingMenu() } }
        .sheet(isPresented: $addingRoom) { RoomEditorView(room: nil) }
        .sheet(item: $editingRoom) { RoomEditorView(room: $0) }
        .sheet(isPresented: $showingSettings) { PricingSettingsView(settings: store.selectedBuilding.settings) }
        .sheet(isPresented: $addingBuilding) { BuildingEditorView(building: nil) }
        .sheet(item: $editingBuilding) { BuildingEditorView(building: $0) }
        .fileExporter(isPresented: $showingExporter, document: exportDocument, contentType: exportType, defaultFilename: exportFilename) { result in
            switch result {
            case .success: message = exportType == .pdf ? "留档 PDF 已保存" : "备份已保存"
            case .failure(let error): message = "保存失败：\(error.localizedDescription)"
            }
            exportDocument = nil
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.zip]) { result in
            do {
                let url = try result.get()
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                pendingRestore = try BackupArchive.importArchive(from: url)
            }
            catch { message = "导入失败：\(error.localizedDescription)" }
        }
        .alert("覆盖当前全部数据？", isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } })) {
            Button("取消", role: .cancel) { pendingRestore = nil }
            Button("确认覆盖", role: .destructive) {
                if let pendingRestore { store.replaceAll(with: pendingRestore) }
                pendingRestore = nil
                message = "备份恢复完成"
            }
        } message: {
            if let value = pendingRestore {
                Text("将恢复 \(value.buildings.count) 栋楼、\(value.rooms.count) 个房间和 \(value.bills.count) 张历史账单。")
            }
        }
    }

    private func exportBackup() {
        let data = store.data
        exporting = true
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    let url = try BackupArchive.export(data)
                    return (try Data(contentsOf: url), url.lastPathComponent)
                }.value
                exportDocument = ExportDocument(data: result.0)
                exportType = .zip
                exportFilename = result.1
                showingExporter = true
            } catch { message = "导出失败：\(error.localizedDescription)" }
            exporting = false
        }
    }

    private func exportPDF() {
        let building = store.selectedBuilding
        let rooms = store.rooms()
        let bills = store.bills()
        let start = pdfStart
        let end = pdfEnd
        exporting = true
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    let url = try ArchivePDFRenderer.write(building: building, rooms: rooms, bills: bills, start: start, end: end)
                    return (try Data(contentsOf: url), url.lastPathComponent)
                }.value
                exportDocument = ExportDocument(data: result.0)
                exportType = .pdf
                exportFilename = result.1
                showingExporter = true
            } catch { message = "PDF 导出失败：\(error.localizedDescription)" }
            exporting = false
        }
    }
}

private struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.zip, .pdf] }
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct MonthStepper: View {
    let title: String
    @Binding var month: MonthValue
    var body: some View {
        Stepper {
            LabeledContent(title) {
                Text(month.id).monospacedDigit()
            }
        } onIncrement: {
            month = month.next
        } onDecrement: {
            month = month.previous
        }
    }
}
