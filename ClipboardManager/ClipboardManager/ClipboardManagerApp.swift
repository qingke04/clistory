import SwiftUI

/// 历史粘贴板 —— macOS 菜单栏应用
/// SwiftUI 标准场景：MenuBarExtra（面板）+ Window（主窗口）+ Settings（设置）
@main
struct ClipboardManagerApp: App {
    /// 系统集成桥接：生命周期、全局快捷键、自动清理
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 菜单栏图标 → 点击弹出历史面板
        MenuBarExtra {
            MenuBarPanelView()
        } label: {
            Image(systemName: "clipboard")
        }
        .menuBarExtraStyle(.window)

        // 主管理窗口
        // 不自定义 .appSettings 命令：Settings 场景会自动在应用菜单生成唯一「设置…」（⌘,）
        Window("历史粘贴板", id: "main") {
            MainContentView()
                .frame(minWidth: 680, minHeight: 480)
        }
        .defaultSize(width: 680, height: 480)

        // 系统标准设置窗口
        Settings {
            SettingsView()
        }
    }
}
