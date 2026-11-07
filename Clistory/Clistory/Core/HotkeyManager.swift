import Carbon
import AppKit
import Observation

/// 全局快捷键管理器
/// 使用 Carbon Event HotKey API 注册系统级热键
@Observable
final class HotkeyManager {
    // MARK: - 单例

    static let shared = HotkeyManager()

    // MARK: - 热键定义

    /// 快捷键组合结构
    struct HotkeyCombo: Codable, Equatable {
        /// 按键虚拟码（Carbon key code）
        var keyCode: Int
        /// 修饰键（carbonModifiers 格式）
        var modifiers: Int

        /// 默认快捷键：Cmd+Shift+V
        static let `default` = HotkeyCombo(
            keyCode: 9,  // kVK_ANSI_V
            modifiers: cmdKey | shiftKey
        )

        /// 用户友好显示字符串
        var displayString: String {
            var parts: [String] = []
            if modifiers & cmdKey != 0 { parts.append("Cmd") }
            if modifiers & shiftKey != 0 { parts.append("Shift") }
            if modifiers & optionKey != 0 { parts.append("Option") }
            if modifiers & controlKey != 0 { parts.append("Ctrl") }

            // 将 Carbon keyCode 转为可读字符
            let keyName = keyCodeToName(keyCode)
            parts.append(keyName)

            return parts.joined(separator: " + ")
        }
    }

    // MARK: - 状态

    /// 当前快捷键（@Observable，设置页展示可自动刷新）
    private(set) var currentHotkey: HotkeyCombo = .default

    /// Carbon 热键引用 ID
    private var hotkeyRef: EventHotKeyRef?

    /// 是否已注册
    private(set) var isRegistered = false

    /// 事件监听器引用
    private var eventHandlerRef: EventHandlerRef?

    // MARK: - 初始化

    private init() {
        loadSavedHotkey()
    }

    // MARK: - 公开方法

    /// 注册全局热键
    func register() {
        unregister()  // 先移除旧的

        // 注册事件处理器
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return -1 }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handleHotkeyPress()
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )

        // 注册具体热键
        let status = RegisterEventHotKey(
            UInt32(currentHotkey.keyCode),
            UInt32(currentHotkey.modifiers),
            EventHotKeyID(signature: 1869372004, id: 1),  // 'clip' = 1869372004
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        if status == noErr {
            isRegistered = true
            print("⌨️ 全局快捷键已注册: \(currentHotkey.displayString)")
        } else {
            print("❌ 快捷键注册失败 (错误码: \(status))")
        }
    }

    /// 注销全局热键
    func unregister() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
        isRegistered = false
    }

    /// 更新快捷键
    func updateHotkey(_ combo: HotkeyCombo) {
        currentHotkey = combo
        saveHotkey(combo)
        register()
    }

    /// 重置为默认快捷键
    func resetToDefault() {
        updateHotkey(.default)
    }

    // MARK: - 热键触发

    private func handleHotkeyPress() {
        DispatchQueue.main.async {
            AppWindows.showPanel()
        }
    }

    // MARK: - 持久化

    /// 从 UserDefaults 加载已保存的快捷键
    private func loadSavedHotkey() {
        guard let data = UserDefaults.standard.data(forKey: "hotkey_combo"),
              let combo = try? JSONDecoder().decode(HotkeyCombo.self, from: data) else {
            currentHotkey = .default
            return
        }
        currentHotkey = combo
    }

    /// 保存快捷键到 UserDefaults
    private func saveHotkey(_ combo: HotkeyCombo) {
        guard let data = try? JSONEncoder().encode(combo) else { return }
        UserDefaults.standard.set(data, forKey: "hotkey_combo")
    }
}

// MARK: - Key Code → 可读名称

/// 将 Carbon 虚拟键码转为可读字符串
private func keyCodeToName(_ code: Int) -> String {
    switch code {
    case 0:  return "A"
    case 1:  return "S"
    case 2:  return "D"
    case 3:  return "F"
    case 4:  return "H"
    case 5:  return "G"
    case 6:  return "Z"
    case 7:  return "X"
    case 8:  return "C"
    case 9:  return "V"
    case 11: return "B"
    case 12: return "Q"
    case 13: return "W"
    case 14: return "E"
    case 15: return "R"
    case 16: return "Y"
    case 17: return "T"
    case 31: return "O"
    case 32: return "U"
    case 34: return "I"
    case 35: return "P"
    case 37: return "L"
    case 38: return "J"
    case 40: return "K"
    case 45: return "N"
    case 46: return "M"
    case 49: return "Space"
    case 36: return "Return"
    case 48: return "Tab"
    case 51: return "Delete"
    case 53: return "Esc"
    case 122: return "F1"; case 120: return "F2"; case 99: return "F3"
    case 118: return "F4"; case 96: return "F5"; case 97: return "F6"
    case 98: return "F7"; case 100: return "F8"; case 101: return "F9"
    case 109: return "F10"; case 103: return "F11"; case 111: return "F12"
    case 123: return "←"; case 124: return "→"; case 125: return "↓"; case 126: return "↑"
    default:  return "Key(\(code))"
    }
}
