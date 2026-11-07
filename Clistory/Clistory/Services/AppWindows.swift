import AppKit

/// 窗口导航辅助 —— 供视图、快捷键、菜单统一打开界面
enum AppWindows {

    /// 打开主窗口
    static func openMain() {
        AppDelegate.shared?.openMainWindow()
    }

    /// 显示快捷面板
    static func showPanel() {
        AppDelegate.shared?.showPanel()
    }
}
