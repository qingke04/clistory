import SwiftUI
import AppKit

/// 菜单栏弹出面板 —— 搜索 + 历史列表 + 底部工具栏
/// 纯 SwiftUI 实现，由 MenuBarExtra / 快捷面板窗口承载
struct MenuBarPanelView: View {
    private let storage = StorageManager.shared
    @State private var searchText = ""

    private var filteredItems: [ClipboardItem] {
        ClipboardActions.filter(storage.getSortedItems(), query: searchText)
    }

    private var pinnedItems: [ClipboardItem] {
        filteredItems.filter(\.isPinned)
    }

    private var normalItems: [ClipboardItem] {
        filteredItems.filter { !$0.isPinned }
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchFieldView(text: $searchText)
                .padding(12)

            contentList

            Divider()
            bottomToolbar
        }
        .frame(width: 320, height: 480)
    }

    // MARK: - 列表

    @ViewBuilder
    private var contentList: some View {
        if filteredItems.isEmpty {
            EmptyStateView(isSearching: !searchText.isEmpty)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if !pinnedItems.isEmpty {
                        pinnedSectionHeader
                        ForEach(pinnedItems) { item in
                            ClipboardItemCard(item: item)
                        }
                        if !normalItems.isEmpty {
                            Divider()
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                        }
                    }

                    ForEach(normalItems) { item in
                        ClipboardItemCard(item: item)
                    }
                }
            }
        }
    }

    private var pinnedSectionHeader: some View {
        HStack {
            Image(systemName: "pin.fill")
                .font(.caption2)
                .foregroundStyle(.tint)
            Text("已置顶")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 4)
    }

    // MARK: - 底部工具栏

    private var bottomToolbar: some View {
        HStack {
            Text("共 \(storage.items.count) 条记录")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                AppWindows.openMain()
            } label: {
                Image(systemName: "macwindow")
            }
            .buttonStyle(.plain)
            .help("打开主界面")

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.plain)
            .help("退出应用")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.3))
    }
}

#Preview {
    MenuBarPanelView()
}
