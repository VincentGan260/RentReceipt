import SwiftUI

enum AppPalette {
    static let blue = Color(uiColor: .systemBlue)
    static let aqua = Color(uiColor: .systemTeal)
    static let violet = Color(uiColor: .systemPurple)
}

struct ModalCancelButton: View {
    let action: () -> Void
    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            Button(role: .cancel, action: action) {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("取消")
        } else {
            Button("取消", role: .cancel, action: action)
        }
    }
}

struct ModalConfirmButton: View {
    var title = "保存"
    var enabled = true
    let action: () -> Void
    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: action) {
                Image(systemName: "checkmark")
            }
            .buttonStyle(.glassProminent)
            .tint(AppPalette.blue)
            .disabled(!enabled)
            .accessibilityLabel(title)
        } else {
            Button(title, action: action)
                .foregroundStyle(AppPalette.blue)
                .tint(AppPalette.blue)
                .fontWeight(.semibold)
                .disabled(!enabled)
        }
    }
}

struct AppBackground: View {
    var body: some View {
        Color(uiColor: .systemGroupedBackground)
            .ignoresSafeArea()
    }
}

struct AppCard<Content: View>: View {
    @ViewBuilder var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 28, style: .continuous)
            )
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let detail: String
    @ViewBuilder
    var body: some View {
        if #available(iOS 17.0, *) {
            ContentUnavailableView {
                Label(title, systemImage: icon)
            } description: {
                Text(detail)
            }
        } else {
            GroupBox {
                VStack(spacing: 12) {
                    Image(systemName: icon).font(.system(size: 36)).foregroundStyle(AppPalette.blue)
                    Text(title).font(.title3.bold())
                    Text(detail).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            }
        }
    }
}

struct BuildingMenu: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        Menu {
            ForEach(store.data.buildings) { building in
                Button {
                    store.selectedBuildingID = building.id
                } label: {
                    if store.selectedBuildingID == building.id {
                        Label(building.name, systemImage: "checkmark")
                    } else { Text(building.name) }
                }
            }
        } label: {
            Label(store.selectedBuilding.name, systemImage: "building.2.fill")
                .font(.subheadline.weight(.semibold))
        }
    }
}

struct CurrencyText: View {
    let value: String
    var body: some View {
        Text("¥\(value)").monospacedDigit()
    }
}

/// Keeps compact controls horizontal at ordinary text sizes, then gives each
/// control a full row when the user selects an accessibility text size.
struct AdaptiveStack<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var spacing: CGFloat = 10
    @ViewBuilder var content: Content

    init(spacing: CGFloat = 10, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: spacing) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: spacing) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension View {
    @ViewBuilder
    func softTitleScrollEdge() -> some View {
        if #available(iOS 26.0, *) {
            scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self
        }
    }

    @ViewBuilder
    func prominentGlassButton() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent)
                .tint(AppPalette.blue)
        } else {
            buttonStyle(.borderless)
                .foregroundStyle(AppPalette.blue)
        }
    }
}
