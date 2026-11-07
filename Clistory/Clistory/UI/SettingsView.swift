import SwiftUI
import AppKit
import ServiceManagement
import Carbon

/// 快捷键录制协调器 —— 处理 NSEvent 监听生命周期
@Observable
private final class HotkeyRecorder {
    private var monitor: Any?

    func startRecording(onCapture: @escaping (HotkeyManager.HotkeyCombo) -> Void) {
        stopRecording()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
                return nil
            }

            let modifiers = event.modifierFlags
            let keyCode = Int(event.keyCode)

            var carbonModifiers: Int = 0
            if modifiers.contains(.command) { carbonModifiers |= cmdKey }
            if modifiers.contains(.shift) { carbonModifiers |= shiftKey }
            if modifiers.contains(.option) { carbonModifiers |= optionKey }
            if modifiers.contains(.control) { carbonModifiers |= controlKey }

            let combo = HotkeyManager.HotkeyCombo(keyCode: keyCode, modifiers: carbonModifiers)
            onCapture(combo)
            return nil
        }
    }

    func stopRecording() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
        }
        monitor = nil
    }

    deinit {
        stopRecording()
    }
}

/// 应用设置 —— Form 标准布局
/// 存储时长支持「无限制」选项；顶部提供语言设置（跟随系统 / 简体中文 / English）
struct SettingsView: View {
    // MARK: - 设置项

    /// 存储天数；**0 = 无限制（不按时间删除）**，默认 1 天
    @AppStorage("retentionDays") private var retentionDays: Int = 1

    /// 存储条数上限（0 = 无上限）
    @AppStorage("maxItemCount") private var maxItemCount: Int = 0

    /// 开机自启动
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    /// 是否正在录制快捷键
    @State private var isRecordingHotkey = false

    /// 快捷键展示（HotkeyManager 为 @Observable，变更后自动刷新）
    private let hotkeyManager = HotkeyManager.shared

    /// 语言设置（@Observable，切换后界面即时刷新）
    private let languageManager = LanguageManager.shared

    @State private var recorder = HotkeyRecorder()

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1"
    }

    // MARK: - 主体

    var body: some View {
        Form {
            languageSection
            retentionSection
            maxCountSection
            hotkeySection
            startupSection
            aboutSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 540)
    }

    // MARK: - 语言

    private var languageSection: some View {
        Section {
            Picker(selection: languageBinding) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            } label: {
                Text(L("settings.language.picker"))
            }
            .pickerStyle(.menu)
        } header: {
            Label {
                Text(L("settings.language.section"))
            } icon: {
                Image(systemName: "globe")
            }
        } footer: {
            Text(L("settings.language.footer"))
        }
    }

    /// 语言选择绑定：切换后若实际语言发生变化，弹出重启提示
    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { languageManager.setting },
            set: { newValue in
                if languageManager.setLanguage(newValue) {
                    presentRestartPrompt()
                }
            }
        )
    }

    // MARK: - 存储时长（含「无限制」）

    private var retentionSection: some View {
        Section {
            Picker(selection: $retentionDays) {
                ForEach(retentionOptions, id: \.days) { option in
                    Text(option.label).tag(option.days)
                }
            } label: {
                Text(L("settings.retention.picker"))
            }
            .pickerStyle(.segmented)
        } header: {
            Label {
                Text(L("settings.retention.section"))
            } icon: {
                Image(systemName: "clock")
            }
        } footer: {
            Text(retentionFooterText)
        }
    }

    /// 可选保留天数：0 = 无限制（排在最右）
    private var retentionOptions: [(days: Int, label: String)] {
        [
            (1, L("settings.retention.day1")),
            (5, L("settings.retention.day5")),
            (7, L("settings.retention.day7")),
            (30, L("settings.retention.day30")),
            (0, L("settings.retention.unlimited"))
        ]
    }

    private var retentionFooterText: String {
        guard retentionDays > 0 else {
            return L("settings.retention.footer.unlimited")
        }

        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -retentionDays,
            to: Date()
        ) ?? Date()

        let formatter = DateFormatter()
        formatter.locale = languageManager.locale
        formatter.dateFormat = "MM-dd HH:mm"
        return String(format: L("settings.retention.footer.auto"), formatter.string(from: cutoff))
    }

    // MARK: - 存储条数

    private var maxCountSection: some View {
        Section {
            Picker(selection: $maxItemCount) {
                ForEach(maxCountOptions, id: \.count) { option in
                    Text(option.label).tag(option.count)
                }
            } label: {
                Text(L("settings.maxCount.picker"))
            }
            .pickerStyle(.segmented)
        } header: {
            Label {
                Text(L("settings.maxCount.section"))
            } icon: {
                Image(systemName: "tray.full")
            }
        } footer: {
            if maxItemCount > 0 {
                Text(String(format: L("settings.maxCount.footer.limited"), maxItemCount))
            } else {
                Text(L("settings.maxCount.footer.unlimited"))
            }
        }
    }

    /// 可选存储条数上限
    private var maxCountOptions: [(count: Int, label: String)] {
        [10, 20, 50, 100, 200].map { count in
            (count, String(format: L("settings.maxCount.option"), count))
        } + [(0, L("settings.maxCount.unlimited"))]
    }

    // MARK: - 快捷键

    private var hotkeySection: some View {
        Section {
            HStack(spacing: 12) {
                Text(isRecordingHotkey ? L("settings.hotkey.recording") : hotkeyManager.currentHotkey.displayString)
                    .font(.system(.title3, design: .monospaced))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isRecordingHotkey
                                  ? Color.accentColor.opacity(0.15)
                                  : Color.primary.opacity(0.08))
                    )

                Button(isRecordingHotkey ? L("settings.hotkey.cancel") : L("settings.hotkey.record")) {
                    if isRecordingHotkey {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                }
                .controlSize(.small)

                Button(L("settings.hotkey.reset")) {
                    HotkeyManager.shared.resetToDefault()
                    isRecordingHotkey = false
                }
                .buttonStyle(.link)
                .controlSize(.small)
            }
        } header: {
            Label {
                Text(L("settings.hotkey.section"))
            } icon: {
                Image(systemName: "command")
            }
        } footer: {
            Text(L("settings.hotkey.footer"))
        }
    }

    // MARK: - 开机自启动

    private var startupSection: some View {
        Section {
            Toggle(isOn: $launchAtLogin) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("settings.startup.toggle"))
                    Text(L("settings.startup.subtitle"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: launchAtLogin) { _, newValue in
                toggleLaunchAtLogin(newValue)
            }
        } header: {
            Label {
                Text(L("settings.startup.section"))
            } icon: {
                Image(systemName: "power.circle")
            }
        }
    }

    // MARK: - 关于

    private var aboutSection: some View {
        Section {
            LabeledContent {
                HStack(spacing: 8) {
                    Image(systemName: "clipboard")
                        .foregroundStyle(.tint)
                    Text(L("app.name"))
                }
            } label: {
                Text(L("settings.about.app"))
            }
            LabeledContent {
                Text(appVersion)
                    .foregroundStyle(.secondary)
            } label: {
                Text(L("settings.about.version"))
            }
            LabeledContent {
                Text(L("settings.about.descriptionValue"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } label: {
                Text(L("settings.about.description"))
            }
        } header: {
            Label {
                Text(L("settings.about.section"))
            } icon: {
                Image(systemName: "info.circle")
            }
        }
    }

    // MARK: - 快捷键录制

    private func startRecording() {
        isRecordingHotkey = true
        recorder.startRecording { combo in
            DispatchQueue.main.async {
                HotkeyManager.shared.updateHotkey(combo)
                isRecordingHotkey = false
            }
        }
    }

    private func stopRecording() {
        recorder.stopRecording()
        isRecordingHotkey = false
    }

    // MARK: - 重启提示

    /// 语言切换后弹出重启提示：默认按钮「立即重启」，Esc / 次按钮为「稍后重启」
    /// 「稍后重启」时当前界面已即时切换，系统级文案等待下次启动更新
    private func presentRestartPrompt() {
        let alert = NSAlert()
        alert.messageText = L("settings.restart.title")
        alert.informativeText = L("settings.restart.message")
        alert.alertStyle = .informational
        alert.addButton(withTitle: L("settings.restart.now"))
        alert.addButton(withTitle: L("settings.restart.later"))
        alert.buttons.last?.keyEquivalent = "\u{1b}"
        alert.buttons.first?.keyEquivalent = "\r"

        let handleResponse: (NSApplication.ModalResponse) -> Void = { response in
            if response == .alertFirstButtonReturn {
                AppDelegate.shared?.relaunchApp()
            }
        }

        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window, completionHandler: handleResponse)
        } else {
            handleResponse(alert.runModal())
        }
    }

    // MARK: - 自启动控制

    private func toggleLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("❌ 开机自启动设置失败: \(error.localizedDescription)")
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

#Preview {
    SettingsView()
}
