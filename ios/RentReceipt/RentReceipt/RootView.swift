import SwiftUI

enum MainTab: Hashable { case overview, entry, rooms, search }

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selection = MainTab.overview
    @State private var searchSource = MainTab.overview
    @State private var query = ""

    var body: some View {
        Group {
            if store.data.buildings.isEmpty {
                NavigationStack { EmptyBuildingsView() }
            } else {
                if #available(iOS 26.0, *) {
                    searchTabs
                } else {
                    legacyTabs
                }
            }
        }
        .onChange(of: selection) { value in
            if value != .search { searchSource = value; query = "" }
        }
        .onChange(of: store.selectedBuildingID) { _ in query = "" }
        .alert("数据保存失败", isPresented: Binding(
            get: { store.lastPersistenceError != nil },
            set: { if !$0 { store.dismissPersistenceError() } }
        )) {
            Button("好", role: .cancel) { store.dismissPersistenceError() }
        } message: {
            Text(store.lastPersistenceError ?? "请稍后重试。")
        }
    }

    @available(iOS 26.0, *)
    private var searchTabs: some View {
        TabView(selection: $selection) {
            Tab("概览", systemImage: "house.fill", value: MainTab.overview) {
                NavigationStack { OverviewView() }
            }
            Tab("录入", systemImage: "rectangle.and.pencil.and.ellipsis", value: MainTab.entry) {
                NavigationStack { EntryView() }
            }
            Tab("房间", systemImage: "door.left.hand.open", value: MainTab.rooms) {
                NavigationStack { RoomsView() }
            }
            Tab("搜索", systemImage: "magnifyingglass", value: MainTab.search, role: .search) {
                NavigationStack { searchContent }
            }
        }
        .searchable(text: $query, prompt: "搜索房间号")
        .tabViewSearchActivation(.searchTabSelection)
    }

    private var legacyTabs: some View {
        TabView(selection: $selection) {
            NavigationStack { OverviewView() }
                .tabItem { Label("概览", systemImage: "house.fill") }.tag(MainTab.overview)
            NavigationStack { EntryView() }
                .tabItem { Label("录入", systemImage: "rectangle.and.pencil.and.ellipsis") }.tag(MainTab.entry)
            NavigationStack { RoomsView() }
                .tabItem { Label("房间", systemImage: "door.left.hand.open") }.tag(MainTab.rooms)
            NavigationStack {
                searchContent.searchable(text: $query, prompt: "搜索房间号")
            }
                .tabItem { Label("搜索", systemImage: "magnifyingglass") }.tag(MainTab.search)
        }
    }

    @ViewBuilder
    private var searchContent: some View {
        switch searchSource {
        case .entry: EntryView(search: query)
        case .rooms: RoomsView(search: query)
        default: OverviewView(search: query)
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
