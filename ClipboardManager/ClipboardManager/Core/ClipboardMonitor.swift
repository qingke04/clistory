import AppKit
import Observation

/// 剪贴板监听器 —— 定时检测系统剪贴板变化并自动记录
@Observable
final class ClipboardMonitor {
    // MARK: - 单例

    static let shared = ClipboardMonitor()

    // MARK: - 状态

    /// 是否正在监听
    private(set) var isMonitoring = false

    /// 上次检测到的 changeCount，用于判断是否有新内容
    private var lastChangeCount: Int = -1

    /// 上一条记录的文字内容，用于去重
    private var lastTextContent: String?

    /// 定时器引用
    private var timer: Timer?

    /// 轮询间隔（秒）
    private let pollingInterval: TimeInterval = 0.5

    // MARK: - 初始化

    private init() {}

    // MARK: - 公开方法

    /// 开始监听剪贴板
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        // 记录初始 changeCount，避免启动时立即记录已有内容
        lastChangeCount = NSPasteboard.general.changeCount
        lastTextContent = nil

        timer = Timer.scheduledTimer(
            withTimeInterval: pollingInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkClipboard()
        }

        print("👀 剪贴板监听已启动")
    }

    /// 程序化写入剪贴板后调用，更新内部 changeCount 避免重复记录
    func acknowledgeProgrammaticWrite() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    /// 停止监听剪贴板
    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        timer?.invalidate()
        timer = nil
        print("👀 剪贴板监听已停止")
    }

    // MARK: - 剪贴板检测

    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount

        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        // 优先级 1：文件（Finder 复制的文件/文件夹）
        if handleFileFromPasteboard(pasteboard) {
            return
        }

        // 优先级 2：文本（纯文本或富文本提取的纯文本）
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            handleTextContent(text)
            return
        }

        // 优先级 3：其他类型（含纯图片数据）→ 跳过不记录
    }

    // MARK: - 文字处理

    private func handleTextContent(_ text: String) {
        guard text != lastTextContent else { return }
        lastTextContent = text

        let item = ClipboardItem(text: text)
        StorageManager.shared.addItem(item)
        print("📝 记录文字: \"\(item.preview)\"")
    }

    // MARK: - 文件处理

    /// 检测并处理剪贴板中的文件内容
    /// - Returns: 成功处理返回 true
    private func handleFileFromPasteboard(_ pasteboard: NSPasteboard) -> Bool {
        guard pasteboard.string(forType: .fileURL) != nil else {
            return false
        }

        var filePaths: [String] = []
        var fileNames: [String] = []

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL] {
            for url in urls {
                let path = url.path
                let name = url.lastPathComponent

                // 过滤隐藏文件（以 . 开头）
                if name.hasPrefix(".") { continue }

                filePaths.append(path)
                fileNames.append(name)
            }
        } else {
            if let urlString = pasteboard.string(forType: .fileURL),
               let url = URL(string: urlString) {
                let path = url.path
                let name = url.lastPathComponent
                if !name.hasPrefix(".") {
                    filePaths.append(path)
                    fileNames.append(name)
                }
            }
        }

        guard !filePaths.isEmpty else {
            print("⚠️ 剪贴板中的文件被过滤（可能是隐藏文件）")
            return false
        }

        let item = ClipboardItem(filePaths: filePaths, fileNames: fileNames)
        StorageManager.shared.addItem(item)
        lastTextContent = nil

        if filePaths.count == 1 {
            print("📁 记录文件: \(fileNames[0])")
        } else {
            print("📁 记录文件: \(fileNames[0]) 等\(filePaths.count)个文件")
        }

        return true
    }
}
