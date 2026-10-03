import SwiftUI

enum MainTab: Hashable { case overview, entry, rooms }

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selection = MainTab.overview

    var body: some View {
        Group {
            if store.data.buildings.isEmpty {
                NavigationStack { EmptyBuildingsView() }
            } else {
                TabView(selection: $selection) {
                    NavigationStack { OverviewView() }
                        .tabItem { Label("概览", systemImage: "house.fill") }
                        .tag(MainTab.overview)
                    NavigationStack { EntryView() }
                        .tabItem { Label("录入", systemImage: "rectangle.and.pencil.and.ellipsis") }
                        .tag(MainTab.entry)
                    NavigationStack { RoomsView() }
                        .tabItem { Label("房间", systemImage: "door.left.hand.open") }
                        .tag(MainTab.rooms)
                }
            }
        }
        .alert("数据保存失败", isPresented: Binding(
            get: { store.lastPersistenceError != nil },
            set: { if !$0 { store.dismissPersistenceError() } }
        )) {
            Button("好", role: .cancel) { store.dismissPersistenceError() }
        } message: {
            Text(store.lastPersistenceError ?? "请稍后重试。")
        }
    }
}

private struct EmptyBuildingsView: View {
    @State private var addingBuilding = false

    var body: some View {
        ZStack {
            AppBackground()
            EmptyState(
                icon: "building.2",
                title: "还没有楼栋",
                detail: "新增楼栋后即可管理房间和录入账单。"
            )
            .padding(24)
        }
        .navigationTitle("房租管理")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { addingBuilding = true } label: {
                    Label("新增楼栋", systemImage: "plus")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button("新增楼栋") { addingBuilding = true }
                .prominentGlassButton()
                .padding()
        }
        .sheet(isPresented: $addingBuilding) { BuildingEditorView(building: nil) }
    }
}
