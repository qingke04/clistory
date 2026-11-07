import Foundation
import AppKit
import Observation

/// 存储管理器 —— 负责剪贴板历史记录的持久化和读写
/// 元数据存储于 UserDefaults，文件记录存储路径而非副本
@Observable
final class StorageManager {
    // MARK: - 单例

    static let shared = StorageManager()

    // MARK: - 状态

    /// 所有记录（内存中），变更时自动触发依赖该属性的 SwiftUI 视图更新
    private(set) var items: [ClipboardItem] = []

    // MARK: - 存储 Key

    private let userDefaultsKey = "clipboard_items"

    // MARK: - 旧版图片存储目录（向后兼容）

    /// 旧版图片文件存储根目录（仅用于兼容旧数据清理）
    private var imagesDirectory: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        return appSupport
            .appendingPathComponent("ClipboardManager")
            .appendingPathComponent("Images")
    }

    // MARK: - 初始化

    private init() {
        loadFromDisk()
        migrateOldDataIfNeeded()
    }

    // MARK: - 公开方法

    /// 添加新记录
    /// - Returns: 新添加的 ClipboardItem
    @discardableResult
    func addItem(_ item: ClipboardItem) -> ClipboardItem {
        items.insert(item, at: 0)
        saveToDisk()
        let maxCount = UserDefaults.standard.integer(forKey: "maxItemCount")
        enforceMaxCount(maxCount)
        return item
    }

    /// 执行存储条数上限：超出时删除最旧的非置顶记录
    /// - Parameter maxCount: 上限条数；0 或负数表示无上限
    func enforceMaxCount(_ maxCount: Int) {
        guard maxCount > 0 else { return }
        let unpinned = items.filter { !$0.isPinned }
        guard unpinned.count > maxCount else { return }
        let toRemove = unpinned.suffix(unpinned.count - maxCount)
        for item in toRemove {
            deleteItem(item)
        }
        if !toRemove.isEmpty {
            print("🧹 超出存储上限(\(maxCount))，自动清理了 \(toRemove.count) 条旧记录")
        }
    }

    /// 删除指定记录
    func deleteItem(_ item: ClipboardItem) {
        // 旧版图片类型：同步删除本地保存的图片文件
        if item.type == .image, let fileName = item.imageFileName {
            let fileURL = imagesDirectory.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: fileURL)
        }
        // 文件类型（.file）不删除源文件，只删除记录

        items.removeAll { $0.id == item.id }
        saveToDisk()
    }

    /// 验证文件路径是否存在
    /// - Parameter paths: 文件路径数组
    /// - Returns: 所有文件都存在返回 true，否则返回 false
    func validateFiles(_ paths: [String]?) -> Bool {
        guard let paths = paths, !paths.isEmpty else { return false }
        let fm = FileManager.default
        return paths.allSatisfy { fm.fileExists(atPath: $0) }
    }

    /// 切换置顶状态
    func togglePin(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        saveToDisk()
    }

    /// 获取排序后的记录（置顶在前，时间降序）
    func getSortedItems() -> [ClipboardItem] {
        items.sorted { a, b in
            if a.isPinned != b.isPinned {
                return a.isPinned
            }
            return a.timestamp > b.timestamp
        }
    }

    /// 清理过期记录
    /// - Parameter retentionDays: 保留天数；**0 或负数表示无限制，不按时间清理**
    /// - Returns: 被清理的记录数
    @discardableResult
    func cleanupExpired(retentionDays: Int) -> Int {
        // 0 = 无限制，不根据时间删除历史记录
        guard retentionDays > 0 else { return 0 }

        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -retentionDays,
            to: Date()
        ) ?? Date()

        let expiredItems = items.filter { item in
            !item.isPinned && item.timestamp < cutoffDate
        }

        for item in expiredItems {
            deleteItem(item)
        }

        if !expiredItems.isEmpty {
            print("🧹 清理了 \(expiredItems.count) 条过期记录（保留 \(retentionDays) 天）")
        }

        return expiredItems.count
    }

    // MARK: - 历史数据迁移

    /// 迁移旧版数据：清理旧图片记录和存储目录
    private func migrateOldDataIfNeeded() {
        let migrationKey = "legacy_image_migration_completed"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            return
        }

        print("🔄 开始迁移旧版数据...")

        let oldImageItems = items.filter { $0.type == .image }
        if !oldImageItems.isEmpty {
            for item in oldImageItems {
                if let fileName = item.imageFileName {
                    let fileURL = imagesDirectory.appendingPathComponent(fileName)
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
            items.removeAll { $0.type == .image }
            saveToDisk()
            print("🗑️ 清除了 \(oldImageItems.count) 条旧版图片记录")
        }

        let fm = FileManager.default
        if fm.fileExists(atPath: imagesDirectory.path) {
            try? fm.removeItem(at: imagesDirectory)
            print("🗑️ 删除了旧版图片存储目录")
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
        print("✅ 数据迁移完成")
    }

    // MARK: - 持久化

    /// 从 UserDefaults 加载数据
    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            items = []
            return
        }

        do {
            let decoder = JSONDecoder()
            items = try decoder.decode([ClipboardItem].self, from: data)
            print("📋 加载了 \(items.count) 条历史记录")
        } catch {
            print("❌ 加载数据失败: \(error.localizedDescription)")
            items = []
        }
    }

    /// 写入 UserDefaults
    private func saveToDisk() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(items)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("❌ 保存数据失败: \(error.localizedDescription)")
        }
    }
}
