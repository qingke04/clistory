import SwiftUI

/// 空状态视图 —— 使用系统 ContentUnavailableView 语义
struct EmptyStateView: View {
    /// 是否处于搜索无结果场景
    var isSearching: Bool

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(isSearching
                     ? L("components.empty.noMatch.title")
                     : L("components.empty.empty.title"))
            } icon: {
                Image(systemName: isSearching ? "magnifyingglass" : "tray")
            }
        } description: {
            Text(isSearching
                 ? L("components.empty.noMatch.description")
                 : L("components.empty.empty.description"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("无记录") {
    EmptyStateView(isSearching: false)
        .frame(width: 320, height: 240)
}

#Preview("搜索无结果") {
    EmptyStateView(isSearching: true)
        .frame(width: 320, height: 240)
}
