import AppKit
import SwiftUI

/// 应用委托 —— 系统集成层
/// 负责：服务启动、自动清理、全局快捷键唤起面板、主窗口兜底、动态激活策略
/// 界面本身全部由 SwiftUI Scene（MenuBarExtra / Window / Settings）承载
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 静态弱引用，供外部安全获取
    static weak var shared: AppDelegate?

    /// 快捷键唤起的轻量面板窗口（SwiftUI 内容）
    private var panelWindow: NSWindow?
    /// 主窗口兜底（当 SwiftUI Window Scene 尚未创建时）
    private var mainWindow: NSWindow?
    /// 窗口生命周期观察（用于动态切换 Dock 身份）
    private var windowObservers: [NSObjectProtocol] = []

    /// 关闭最后一个窗口时不退出（菜单栏常驻）
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// 点击 Dock 图标时恢复主窗口
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if hasVisibleWindows {
            NSApp.windows.forEach { window in
                if window.isMiniaturized && isPresentationWindow(window) {
                    window.deminiaturize(nil)
                }
            }
        } else {
            openMainWindow()
        }
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        registerDefaultSettings()
        ClipboardMonitor.shared.startMonitoring()
        HotkeyManager.shared.register()
        performStartupCleanup()
        scheduleCleanupTimer()
        observeWindowLifecycle()

        // 启动时显示主窗口（accessory 下 Window Scene 不会自动前置）
        DispatchQueue.main.async {
            self.openMainWindow()
        }

        print("🚀 历史粘贴板已启动")
    }

    func applicationWillTerminate(_ notification: Notification) {
        ClipboardMonitor.shared.stopMonitoring()
        HotkeyManager.shared.unregister()
        windowObservers.forEach(NotificationCenter.default.removeObserver(_:))
        windowObservers.removeAll()
    }

    // MARK: - 动态激活策略

    /// 有主窗口/设置等常规窗口时：.regular（Dock 图标 + 菜单栏软件名）
    /// 全部关闭后回到 .accessory（纯菜单栏，不占 Dock）
    private func observeWindowLifecycle() {
        let center = NotificationCenter.default
        let sync: (Notification) -> Void = { [weak self] _ in
            // 等系统完成窗口可见性变更后再判断
            DispatchQueue.main.async { self?.syncActivationPolicy() }
        }
        windowObservers.append(center.addObserver(
            forName: NSWindow.willCloseNotification, object: nil, queue: .main, using: sync
        ))
        windowObservers.append(center.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main, using: sync
        ))
        windowObservers.append(center.addObserver(
            forName: NSWindow.didMiniaturizeNotification, object: nil, queue: .main, using: sync
        ))
        windowObservers.append(center.addObserver(
            forName: NSWindow.didDeminiaturizeNotification, object: nil, queue: .main, using: sync
        ))
    }

    /// 是否为需要 Dock / 菜单栏软件名身份的「应用级」窗口
    /// 仅认主窗口与设置窗口，避免 MenuBarExtra 弹出层误升为普通应用
    private func isPresentationWindow(_ window: NSWindow) -> Bool {
        if window === panelWindow { return false }
        guard window.isVisible || window.isMiniaturized else { return false }
        if window === mainWindow { return true }

        // 快捷面板 / 菜单栏弹出层 / 状态栏窗口
        let className = String(describing: type(of: window))
        if className.contains("MenuBar") || className.contains("StatusItem") || className.contains("StatusBar") {
            return false
        }
        if window.styleMask.contains(.utilityWindow) || window.styleMask.contains(.nonactivatingPanel) {
            return false
        }
        if window.level.rawValue >= NSWindow.Level.statusBar.rawValue { return false }

        // 主窗口（SwiftUI Window id / 标题）与设置窗口
        if window.identifier?.rawValue == "main" { return true }
        let title = window.title
        return title == "历史粘贴板" || title.contains("设置") || title.contains("Settings")
    }

    private func hasPresentationWindow() -> Bool {
        NSApp.windows.contains { isPresentationWindow($0) }
    }

    /// 根据当前窗口集合同步激活策略
    private func syncActivationPolicy() {
        if hasPresentationWindow() {
            adoptRegularPresentation(activate: false)
        } else {
            adoptAccessoryPresentation()
        }
    }

    /// 升为普通应用：Dock 图标 + 菜单栏显示「历史粘贴板」
    private func adoptRegularPresentation(activate: Bool) {
        let needsChange = NSApp.activationPolicy() != .regular
        if needsChange {
            NSApp.setActivationPolicy(.regular)
        }
        // 策略刚切换时必须 activate，菜单栏才会显示软件名
        if activate || needsChange {
            NSApp.activate(ignoringOtherApps: true)
        }
    }


    /// 收回菜单栏模式：隐藏 Dock 图标（菜单栏图标保留）
    private func adoptAccessoryPresentation() {
        if NSApp.activationPolicy() != .accessory {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    // MARK: - 默认设置

    /// 注册默认值，保证「未设置过」与「设为 1 天」行为一致
    /// retentionDays：0 = 无限制，1/5/7/30 = 保留天数；默认 1 天
    private func registerDefaultSettings() {
        UserDefaults.standard.register(defaults: [
            "retentionDays": 1,
            "maxItemCount": 0
        ])
    }

    // MARK: - 自动清理

    /// 启动清理：过期记录（支持「无限制」）+ 存储上限
    private func performStartupCleanup() {
        let retentionDays = UserDefaults.standard.integer(forKey: "retentionDays")
        // 0 = 无限制，不根据时间删除
        if retentionDays > 0 {
            let count = StorageManager.shared.cleanupExpired(retentionDays: retentionDays)
            if count > 0 {
                print("🧹 启动清理完成：移除了 \(count) 条过期记录")
            }
        }

        let maxCount = UserDefaults.standard.integer(forKey: "maxItemCount")
        StorageManager.shared.enforceMaxCount(maxCount)
    }

    /// 定时清理（每小时）
    private func scheduleCleanupTimer() {
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            let retentionDays = UserDefaults.standard.integer(forKey: "retentionDays")
            if retentionDays > 0 {
                StorageManager.shared.cleanupExpired(retentionDays: retentionDays)
            }
            let maxCount = UserDefaults.standard.integer(forKey: "maxItemCount")
            StorageManager.shared.enforceMaxCount(maxCount)
        }
    }

    // MARK: - 面板（全局快捷键）

    /// 显示快捷面板（默认 Cmd+Shift+V）
    /// 内容为 SwiftUI（MenuBarPanelView），窗口壳由 AppKit 承载并支持失焦关闭
    func showPanel() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            self.presentPanelWindow()
        }
    }

    /// 显示 / 前置快捷面板窗口
    private func presentPanelWindow() {
        if let win = panelWindow, win.windowNumber > 0 {
            win.makeKeyAndOrderFront(nil)
            return
        }

        let host = NSHostingController(rootView: MenuBarPanelView())
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 480),
            styleMask: [.titled, .fullSizeContentView, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.contentViewController = host
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setFrameAutosaveName("ClipboardPanel")

        // 默认定位到屏幕右上区域
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let size = window.frame.size
            let x = visible.maxX - size.width - 24
            let y = visible.maxY - size.height - 12
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panelWindow = window
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - 主窗口

    /// 打开主窗口 —— 优先前置已有 SwiftUI 窗口，必要时手动创建
    /// 打开期间升为普通应用（Dock 图标 + 菜单栏软件名）
    func openMainWindow() {
        adoptRegularPresentation(activate: true)
        panelWindow?.close()

        // 1. SwiftUI Window Scene 创建的窗口
        if let swiftUIWindow = NSApp.windows.first(where: {
            $0.identifier?.rawValue == "main" || $0.title == "历史粘贴板"
        }), swiftUIWindow.windowNumber > 0 {
            swiftUIWindow.makeKeyAndOrderFront(nil)
            return
        }

        // 2. 手动兜底窗口
        if let win = mainWindow, win.windowNumber > 0 {
            win.makeKeyAndOrderFront(nil)
            return
        }

        // 3. 创建兜底主窗口
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "历史粘贴板"
        window.contentView = NSHostingView(rootView: MainContentView())
        window.center()
        window.setFrameAutosaveName("MainWindow")
        window.isReleasedWhenClosed = false
        mainWindow = window
        window.makeKeyAndOrderFront(nil)
    }
}

// MARK: - 面板失焦自动关闭

extension AppDelegate: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window === panelWindow else { return }
        window.close()
    }
}
