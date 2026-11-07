import Foundation
import Observation

/// 支持的语言（实际生效语言，不含「跟随系统」）
enum SupportedLanguage: String, CaseIterable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    /// 对应 .lproj 目录名
    var lprojName: String { rawValue }
}

/// 语言设置项（设置页的三项）
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    /// 设置页展示名：中英文各自用本语言书写，「跟随系统」跟随当前界面语言
    var displayName: String {
        switch self {
        case .system:
            return L("settings.language.system")
        case .simplifiedChinese:
            return "简体中文"
        case .english:
            return "English"
        }
    }
}

/// 语言管理器
/// 负责：语言设置持久化、即时生效的取词、以及 AppleLanguages 覆盖（供下次启动完全生效）
@Observable
final class LanguageManager {
    static let shared = LanguageManager()

    /// 语言设置持久化键
    static let settingKey = "appLanguage"
    /// 语言即时切换完成通知（AppKit 层用于刷新窗口标题等）
    static let didChangeNotification = Notification.Name("LanguageManagerDidChange")

    /// 当前设置项（持久化值）
    private(set) var setting: AppLanguage
    /// 当前实际生效语言（界面立即使用）
    private(set) var resolved: SupportedLanguage

    @ObservationIgnored private var bundles: [String: Bundle] = [:]

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.settingKey) ?? AppLanguage.system.rawValue
        let setting = AppLanguage(rawValue: saved) ?? .system
        self.setting = setting
        self.resolved = Self.resolveEffective(setting)
    }

    // MARK: - 设置

    /// 更新语言设置并立即生效；返回实际生效语言是否发生变化
    @discardableResult
    func setLanguage(_ newValue: AppLanguage) -> Bool {
        let oldResolved = resolved
        setting = newValue
        UserDefaults.standard.set(newValue.rawValue, forKey: Self.settingKey)
        applyLaunchLanguageOverride(for: newValue)
        resolved = Self.resolveEffective(newValue)
        let changed = resolved != oldResolved
        if changed {
            NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
        }
        return changed
    }

    /// 写入 AppleLanguages 覆盖：下次启动时系统级文案、InfoPlist 本地化名称等随之切换
    private func applyLaunchLanguageOverride(for language: AppLanguage) {
        let defaults = UserDefaults.standard
        switch language {
        case .system:
            defaults.removeObject(forKey: "AppleLanguages")
        case .simplifiedChinese:
            defaults.set(["zh-Hans"], forKey: "AppleLanguages")
        case .english:
            defaults.set(["en"], forKey: "AppleLanguages")
        }
    }

    // MARK: - 取词

    /// 按当前语言取词；缺失时回退英文，仍缺失则返回键名
    func string(_ key: String, table: String) -> String {
        let value = localizedString(key, table: table, language: resolved)
        if value != key { return value }
        if resolved != .english {
            let fallback = localizedString(key, table: table, language: .english)
            if fallback != key { return fallback }
        }
        return key
    }

    /// 当前语言对应的 Locale（日期等格式化使用）
    var locale: Locale {
        switch resolved {
        case .simplifiedChinese:
            return Locale(identifier: "zh_Hans_CN")
        case .english:
            return Locale(identifier: "en_US")
        }
    }

    // MARK: - 内部实现

    private func localizedString(_ key: String, table: String, language: SupportedLanguage) -> String {
        bundle(for: language).localizedString(forKey: key, value: key, table: table)
    }

    /// 懒加载指定语言的 .lproj Bundle
    private func bundle(for language: SupportedLanguage) -> Bundle {
        if let cached = bundles[language.rawValue] { return cached }
        let bundle: Bundle
        if let path = Bundle.main.path(forResource: language.lprojName, ofType: "lproj"),
           let localized = Bundle(path: path) {
            bundle = localized
        } else {
            bundle = Bundle.main
        }
        bundles[language.rawValue] = bundle
        return bundle
    }

    /// 解析设置项对应的实际语言；「跟随系统」读取系统全局 AppleLanguages
    private static func resolveEffective(_ language: AppLanguage) -> SupportedLanguage {
        switch language {
        case .simplifiedChinese:
            return .simplifiedChinese
        case .english:
            return .english
        case .system:
            return systemPreferredLanguage()
        }
    }

    /// 读取系统全局 AppleLanguages（不受本应用内的覆盖影响）
    private static func systemPreferredLanguage() -> SupportedLanguage {
        let identifiers = systemAppleLanguages() ?? Locale.preferredLanguages
        for identifier in identifiers {
            let code = Locale(identifier: identifier).language.languageCode?.identifier
                ?? String(identifier.prefix(2))
            switch code {
            case "zh":
                return .simplifiedChinese
            case "en":
                return .english
            default:
                continue
            }
        }
        // 未知系统语言：回退英文（与 CFBundleDevelopmentRegion 一致）
        return .english
    }

    private static func systemAppleLanguages() -> [String]? {
        CFPreferencesCopyAppValue(
            "AppleLanguages" as CFString,
            kCFPreferencesAnyApplication
        ) as? [String]
    }
}

/// 本地化取词入口
/// 键名格式：`表名小写.完整键`，例如 `L("settings.language.title")`
/// 表名由第一段决定（app / settings / common / main / panel / components），
/// `.strings` 文件中的键名与这里传入的完整键一致。
func L(_ key: String) -> String {
    let parts = key.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
    guard parts.count == 2 else {
        return LanguageManager.shared.string(key, table: "Localizable")
    }
    let table = String(parts[0]).capitalized
    return LanguageManager.shared.string(key, table: table)
}
