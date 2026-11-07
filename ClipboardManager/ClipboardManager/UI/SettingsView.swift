import SwiftUI
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
/// 存储时长支持「无限制」选项
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

    @State private var recorder = HotkeyRecorder()

    /// 可选保留天数：0 = 无限制（排在最右）
    private let retentionOptions: [(days: Int, label: String)] = [
        (1, "1 天"),
        (5, "5 天"),
        (7, "7 天"),
        (30, "30 天"),
        (0, "无限制")
    ]

    /// 可选存储条数上限
    private let maxCountOptions: [(count: Int, label: String)] = [
        (10, "10 条"), (20, "20 条"), (50, "50 条"),
        (100, "100 条"), (200, "200 条"), (0, "无上限")
    ]

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    // MARK: - 主体

    var body: some View {
        Form {
            retentionSection
            maxCountSection
            hotkeySection
            startupSection
            aboutSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 480)
    }

    // MARK: - 存储时长（含「无限制」）

    private var retentionSection: some View {
        Section {
            Picker("保留时长", selection: $retentionDays) {
                ForEach(retentionOptions, id: \.days) { option in
                    Text(option.label).tag(option.days)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Label("存储时长", systemImage: "clock")
        } footer: {
            Text(retentionFooterText)
        }
    }

    private var retentionFooterText: String {
        guard retentionDays > 0 else {
            return "不根据时间删除历史记录。置顶规则与条数上限仍然生效。"
        }

        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -retentionDays,
            to: Date()
        ) ?? Date()

        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return "自动清理：\(formatter.string(from: cutoff)) 之前的非置顶记录将被清理（置顶项不清理）"
    }

    // MARK: - 存储条数

    private var maxCountSection: some View {
        Section {
            Picker("条数上限", selection: $maxItemCount) {
                ForEach(maxCountOptions, id: \.count) { option in
                    Text(option.label).tag(option.count)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Label("存储条数", systemImage: "tray.full")
        } footer: {
            Text(maxItemCount > 0
                 ? "超出 \(maxItemCount) 条时自动清理最旧的非置顶记录；与存储时长可同时生效。"
                 : "不限制存储条数；与存储时长可同时生效。")
        }
    }

    // MARK: - 快捷键

    private var hotkeySection: some View {
        Section {
            HStack(spacing: 12) {
                Text(isRecordingHotkey ? "按下新快捷键..." : hotkeyManager.currentHotkey.displayString)
                    .font(.system(.title3, design: .monospaced))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isRecordingHotkey
                                  ? Color.accentColor.opacity(0.15)
                                  : Color.primary.opacity(0.08))
                    )

                Button(isRecordingHotkey ? "取消" : "录制快捷键") {
                    if isRecordingHotkey {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                }
                .controlSize(.small)

                Button("恢复默认") {
                    HotkeyManager.shared.resetToDefault()
                    isRecordingHotkey = false
                }
                .buttonStyle(.link)
                .controlSize(.small)
            }
        } header: {
            Label("快捷键", systemImage: "command")
        } footer: {
            Text("设置全局快捷键以快速打开历史面板")
        }
    }

    // MARK: - 开机自启动

    private var startupSection: some View {
        Section {
            Toggle(isOn: $launchAtLogin) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("开机自动启动")
                    Text("登录系统后自动在菜单栏中运行")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: launchAtLogin) { _, newValue in
                toggleLaunchAtLogin(newValue)
            }
        } header: {
            Label("启动", systemImage: "power.circle")
        }
    }

    // MARK: - 关于

    private var aboutSection: some View {
        Section {
            LabeledContent("应用") {
                HStack(spacing: 8) {
                    Image(systemName: "clipboard")
                        .foregroundStyle(.tint)
                    Text("历史粘贴板")
                }
            }
            LabeledContent("版本") {
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }
            LabeledContent("简介") {
                Text("一款简洁的 macOS 剪贴板管理工具")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Label("关于", systemImage: "info.circle")
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
