import SwiftUI

enum MainTab: Hashable { case overview, entry, rooms }

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selection = MainTab.overview

    var body: some View {
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
