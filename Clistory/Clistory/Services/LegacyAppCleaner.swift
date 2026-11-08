import AppKit
import ServiceManagement

/// 旧版本应用清理器
///
/// 背景：1.1 起应用英文名由「历史粘贴板」改为「Clistory」，Bundle ID 保持不变
/// （`com.clipboardmanager.app`），而安装包通过 DMG 拖拽安装。因为磁盘上的包文件名
/// 由 `历史粘贴板.app` 变成 `Clistory.app`，升级后「应用程序」文件夹里会同时存在
/// 新旧两个 `.app`（中文系统下 Finder 会把两者都显示为「历史粘贴板」，更难分辨）。
///
/// 本类在应用启动时做一次检测：找到与当前应用同 Bundle ID 的旧版本应用后，
/// 先让仍在运行的旧实例退出（避免两个菜单栏实例同时写同一份历史记录），
/// 再把它移到废纸篓（可恢复，不直接删除），从而消除两个版本共存。
///
/// 提示：macOS 13+ 的「App 管理」隐私保护可能拦截对其它应用的移动操作，
/// 此时会返回失败，由 AppDelegate 弹窗引导用户授权或手动处理。
final class LegacyAppCleaner {
    /// 旧版本的安装包文件名（磁盘上的 `.app` 名，不受 Finder 显示名本地化影响）
    static let legacyBundleNames: Set<String> = [
        "历史粘贴板.app",       // 1.0.x 的产物名
        "ClipboardManager.app"  // 更名前的早期开发版本
    ]

    /// 可能安装应用的目录
    static var applicationDirectories: [URL] {
        [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications", isDirectory: true)
        ]
    }

    /// 清理结果
    struct Result {
        /// 已移入废纸篓的旧版本文件名
        var removed: [String] = []
        /// 自动移除失败的旧版本文件名
        var failed: [String] = []

        var isEmpty: Bool { removed.isEmpty && failed.isEmpty }
    }

    /// 扫描并清理旧版本应用（可能触发磁盘 IO，应在后台线程调用）
    @discardableResult
    static func cleanup() -> Result {
        var result = Result()

        // 1. 扫描旧版本安装包
        let legacyURLs = findLegacyApps()

        // 2. 让仍在运行的旧版实例退出（也覆盖旧包已被手动删除、进程仍在运行的僵尸实例）
        terminateRunningApps(legacyURLs: legacyURLs)

        guard !legacyURLs.isEmpty else { return result }

        // 3. 逐个移到废纸篓（可恢复，不直接 rm）
        for url in legacyURLs {
            do {
                var trashedURL: NSURL?
                try FileManager.default.trashItem(at: url, resultingItemURL: &trashedURL)
                result.removed.append(url.lastPathComponent)
                print("🧹 已移除旧版本应用：\(url.path)")
            } catch {
                result.failed.append(url.lastPathComponent)
                print("❌ 移除旧版本应用失败（\(url.path)）：\(error.localizedDescription)")
            }
        }

        // 4. 旧版删除后重新注册登录项，使其指向新版本
        if !result.removed.isEmpty {
            refreshLoginItemIfNeeded()
        }
        return result
    }

    /// 查找「应用程序」目录中与当前应用同 Bundle ID 的旧版本应用
    /// 只按磁盘文件名匹配，避免误删 Bundle ID 不同的其它应用
    static func findLegacyApps() -> [URL] {
        guard let bundleID = Bundle.main.bundleIdentifier else { return [] }

        let fileManager = FileManager.default
        let currentPath = currentBundleURL.path
        var legacyURLs: [URL] = []

        for directory in applicationDirectories {
            guard let entries = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for entry in entries where entry.pathExtension == "app" {
                guard legacyBundleNames.contains(entry.lastPathComponent) else { continue }
                // 排除当前正在运行的包（防止把自身移入废纸篓）
                guard entry.standardizedFileURL.resolvingSymlinksInPath().path != currentPath else { continue }
                // 必须与当前应用同 Bundle ID，避免误删同名但无关的应用
                guard let candidate = Bundle(url: entry),
                      candidate.bundleIdentifier == bundleID,
                      candidate.bundleURL.standardizedFileURL.resolvingSymlinksInPath().path != currentPath
                else { continue }
                legacyURLs.append(entry)
            }
        }
        return legacyURLs
    }

    /// 终止仍在运行的旧版实例
    /// 判定条件（任一）：位于待清理的旧包路径、包名属于旧命名、或安装包已被删除（僵尸实例）
    /// 返回是否有进程被要求退出；最多等待 2 秒让其正常结束（保存历史记录）
    @discardableResult
    static func terminateRunningApps(legacyURLs: [URL]) -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }

        let legacyPaths = Set(legacyURLs.map { $0.standardizedFileURL.resolvingSymlinksInPath().path })
        let currentURL = currentBundleURL
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let fileManager = FileManager.default

        var running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).filter { app in
            guard app.processIdentifier != currentPID,
                  let bundleURL = app.bundleURL?.standardizedFileURL.resolvingSymlinksInPath(),
                  bundleURL.path != currentURL.path
            else { return false }
            return legacyPaths.contains(bundleURL.path)
                || legacyBundleNames.contains(bundleURL.lastPathComponent)
                || !fileManager.fileExists(atPath: bundleURL.path)
        }
        guard !running.isEmpty else { return false }

        running.forEach { $0.terminate() }

        let deadline = Date().addingTimeInterval(2)
        while !running.isEmpty && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
            running = running.filter { !$0.isTerminated }
        }
        return true
    }

    /// 旧版应用删除后，若曾开启「开机自动启动」，把登录项重新注册到新版本
    /// （登录项按应用记录，旧版本被移除后指针可能失效，需要重新登记一次）
    private static func refreshLoginItemIfNeeded() {
        DispatchQueue.main.async {
            let service = SMAppService.mainApp
            guard service.status == .enabled else { return }
            do {
                try service.unregister()
                try service.register()
                print("🔁 已重新注册开机自启动，指向新版本")
            } catch {
                print("⚠️ 重新注册开机自启动失败：\(error.localizedDescription)")
            }
        }
    }

    /// 当前应用自身的 bundle URL（标准化并解析符号链接，用于排除自己）
    private static var currentBundleURL: URL {
        Bundle.main.bundleURL.standardizedFileURL.resolvingSymlinksInPath()
    }
}
