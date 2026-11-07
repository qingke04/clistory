import Foundation

/// 剪贴板历史记录项
/// 支持文字和文件两种类型
struct ClipboardItem: Codable, Identifiable, Equatable {
    /// 唯一标识
    let id: UUID
    /// 内容类型
    let type: ItemType
    /// 文字内容（仅 type == .text 时有值）
    var textContent: String?

    // MARK: - 旧字段（向后兼容，保留解码能力）
    /// 图片文件名（仅 type == .image 时有值，不含路径）
    var imageFileName: String?
    /// 原始文件名（复制时从文件路径提取，浏览器等来源可能为空）
    var originalImageName: String?
    /// 图片文件大小（字节），仅 .image 类型，用于列表预览
    var imageFileSize: Int?

    // MARK: - 文件路径字段
    /// 文件路径数组（仅 type == .file 时有值）
    var filePaths: [String]?
    /// 文件名数组（用于显示，仅 type == .file 时有值）
    var fileNames: [String]?

    /// 复制时间
    let timestamp: Date
    /// 是否置顶
    var isPinned: Bool

    /// 内容类型枚举
    enum ItemType: String, Codable, CaseIterable {
        case text
        case image  // 保留向后兼容
        case file
    }

    // MARK: - 初始化

    /// 创建文字类型的记录
    init(text: String) {
        self.id = UUID()
        self.type = .text
        self.textContent = text
        self.imageFileName = nil
        self.originalImageName = nil
        self.imageFileSize = nil
        self.filePaths = nil
        self.fileNames = nil
        self.timestamp = Date()
        self.isPinned = false
    }

    /// 创建图片类型的记录（旧版兼容）
    init(imageFileName: String, originalName: String? = nil, fileSize: Int? = nil) {
        self.id = UUID()
        self.type = .image
        self.textContent = nil
        self.imageFileName = imageFileName
        self.originalImageName = originalName
        self.imageFileSize = fileSize
        self.filePaths = nil
        self.fileNames = nil
        self.timestamp = Date()
        self.isPinned = false
    }

    /// 创建文件类型的记录
    init(filePaths: [String], fileNames: [String]) {
        self.id = UUID()
        self.type = .file
        self.textContent = nil
        self.imageFileName = nil
        self.originalImageName = nil
        self.imageFileSize = nil
        self.filePaths = filePaths
        self.fileNames = fileNames
        self.timestamp = Date()
        self.isPinned = false
    }

    // MARK: - 计算属性

    /// 格式化的时间描述（如"刚刚"、"5分钟前"、"1小时前"）
    var formattedTime: String {
        let interval = Date().timeIntervalSince(timestamp)

        switch interval {
        case ..<60:
            return "刚刚"
        case ..<3600:
            let minutes = Int(interval / 60)
            return "\(minutes)分钟前"
        case ..<86400:
            let hours = Int(interval / 3600)
            return "\(hours)小时前"
        case ..<604800:
            let days = Int(interval / 86400)
            return "\(days)天前"
        default:
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd HH:mm"
            return formatter.string(from: timestamp)
        }
    }

    /// 内容预览（用于列表展示，最多显示 80 个字符）
    var preview: String {
        switch type {
        case .text:
            let content = textContent ?? ""
            if content.count <= 80 {
                return content
            } else {
                return String(content.prefix(80)) + "..."
            }
        case .image:
            // 旧版图片记录兼容显示
            if let name = originalImageName, !name.isEmpty {
                return "[图片] \(name)"
            }
            if let size = imageFileSize {
                return "[图片] \(Self.formatFileSize(size))"
            }
            return "[图片]"
        case .file:
            // 文件记录预览
            guard let names = fileNames, !names.isEmpty else {
                return "[文件]"
            }
            let firstName = names[0]
            if names.count == 1 {
                return firstName
            } else {
                return "\(firstName) 等\(names.count)个文件"
            }
        }
    }

    /// 文件扩展名（用于图标显示）
    var fileExtension: String? {
        switch type {
        case .file:
            guard let firstName = fileNames?.first else { return nil }
            return (firstName as NSString).pathExtension.lowercased()
        case .image:
            if let name = originalImageName {
                return (name as NSString).pathExtension.lowercased()
            }
            return nil
        case .text:
            return nil
        }
    }

    /// 是否是图片文件类型
    var isImageFile: Bool {
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "tiff", "heic"]
        guard let ext = fileExtension else { return false }
        return imageExtensions.contains(ext)
    }

    /// 是否是文件夹
    var isFolder: Bool {
        guard type == .file, let paths = filePaths, let firstPath = paths.first else {
            return false
        }
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: firstPath, isDirectory: &isDir) && isDir.boolValue
    }

    /// 格式化文件大小为可读字符串（如 "245KB"、"1.5MB"）
    private static func formatFileSize(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes)B" }
        if bytes < 1024 * 1024 { return "\(bytes / 1024)KB" }
        let mb = Double(bytes) / (1024.0 * 1024.0)
        return String(format: "%.1fMB", mb)
    }
}
