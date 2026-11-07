import AppKit

/// 剪贴板操作服务 —— 主窗口与菜单栏面板共用，避免视图层重复业务逻辑
enum ClipboardActions {

    /// 复制操作结果
    enum CopyResult: Equatable {
        /// 复制成功
        case success
        /// 文件已失效（移动/删除），附带缺失文件名
        case fileMissing([String])
    }

    /// 将记录内容复制到系统剪贴板
    /// - Parameter item: 历史记录
    /// - Returns: 复制结果；`.fileMissing` 时调用方应提示并删除该记录
    @discardableResult
    static func copy(_ item: ClipboardItem) -> CopyResult {
        let pasteboard = NSPasteboard.general

        switch item.type {
        case .text:
            pasteboard.clearContents()
            pasteboard.setString(item.textContent ?? "", forType: .string)
            ClipboardMonitor.shared.acknowledgeProgrammaticWrite()
            return .success

        case .file:
            guard let paths = item.filePaths, !paths.isEmpty,
                  StorageManager.shared.validateFiles(paths) else {
                return .fileMissing(item.fileNames ?? [])
            }

            let fileURLs = paths.map { URL(fileURLWithPath: $0) }
            pasteboard.clearContents()
            pasteboard.writeObjects(fileURLs as [NSPasteboardWriting])
            ClipboardMonitor.shared.acknowledgeProgrammaticWrite()
            return .success

        case .image:
            // 旧版图片记录（迁移后应已清理）：兜底删除，不再支持复制
            StorageManager.shared.deleteItem(item)
            return .fileMissing(item.fileNames ?? [item.preview])
        }
    }

    /// 切换置顶
    static func togglePin(_ item: ClipboardItem) {
        StorageManager.shared.togglePin(item)
    }

    /// 删除记录（不删除源文件）
    static func delete(_ item: ClipboardItem) {
        StorageManager.shared.deleteItem(item)
    }

    /// 过滤搜索
    /// - Parameters:
    ///   - items: 原始记录列表
    ///   - query: 搜索关键字（可空）
    /// - Returns: 过滤后的记录
    static func filter(_ items: [ClipboardItem], query: String) -> [ClipboardItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return items }

        return items.filter { item in
            switch item.type {
            case .text:
                return item.textContent?.lowercased().contains(trimmed) ?? false
            case .image:
                return item.originalImageName?.lowercased().contains(trimmed) ?? false
            case .file:
                return item.fileNames?.contains { $0.lowercased().contains(trimmed) } ?? false
            }
        }
    }
}
