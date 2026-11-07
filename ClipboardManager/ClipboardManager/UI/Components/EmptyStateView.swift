import SwiftUI

/// 空状态视图 —— 使用系统 ContentUnavailableView 语义
struct EmptyStateView: View {
    /// 是否处于搜索无结果场景
    var isSearching: Bool

    var body: some View {
        ContentUnavailableView {
            Label(
                isSearching ? "未找到匹配内容" : "暂无复制记录",
                systemImage: isSearching ? "magnifyingglass" : "tray"
            )
        } description: {
            Text(isSearching
                 ? "试试其他关键词"
                 : "复制文字或文件后会自动出现在这里")
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
