import SwiftUI

/// 主窗口内容 —— 完整历史管理界面（无侧边栏）
/// 设置入口：菜单栏「历史粘贴板」→「设置…」（Settings Scene）
struct MainContentView: View {
    private let storage = StorageManager.shared
    @State private var searchText = ""

    private var filteredItems: [ClipboardItem] {
        ClipboardActions.filter(storage.getSortedItems(), query: searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            SearchFieldView(text: $searchText)
                .padding()

            if filteredItems.isEmpty {
                EmptyStateView(isSearching: !searchText.isEmpty)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredItems) { item in
                            ClipboardItemCard(item: item)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Divider()
            statusBar
        }
        .navigationTitle("历史粘贴板")
    }

    private var headerBar: some View {
        HStack {
            Image(systemName: "clipboard")
                .foregroundStyle(.tint)
            Text("历史粘贴板")
                .font(.headline)
            Spacer()
            Text("共 \(storage.items.count) 条记录")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var statusBar: some View {
        HStack {
            Text("点击卡片可复制到剪贴板")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.2))
    }
}

#Preview {
    MainContentView()
        .frame(minWidth: 680, minHeight: 480)
}
