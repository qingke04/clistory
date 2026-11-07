# 02 — 技术规范

> 本文档描述当前实现（SwiftUI 标准 UI 架构 + 标准 .strings 本地化），适用于 v1.1。

## 1. 技术选型

| 层面 | 选择 | 说明 |
|------|------|------|
| 语言 | Swift 5.9+ | macOS 原生语言 |
| UI 框架 | SwiftUI（标准） | `MenuBarExtra` / `Window` / `Settings` Scene；视图层不写 AppKit UI |
| 状态管理 | Observation `@Observable` | macOS 14 标准，替代 `ObservableObject` |
| 生命周期 | SwiftUI App + AppDelegate | `@main App` 声明 Scene；`AppDelegate` 只做系统集成 |
| 存储 | UserDefaults + FileManager | 元数据 JSON 存 UserDefaults；文件只记路径 |
| 剪贴板 API | AppKit `NSPasteboard` | 系统剪贴板读写 |
| 快捷键 | Carbon `RegisterEventHotKey` | 全局热键注册 |
| 开机启动 | `SMAppService` | macOS 13+ Login Item API |
| 本地化 | 标准 `.strings` + 自建 `LanguageManager` | 6 张业务字符串表 + InfoPlist；应用内即时切换 |
| 最低系统 | macOS 14 Sonoma | 使用 `@Observable`、`ContentUnavailableView`、`MenuBarExtra` |

## 2. 数据模型

```swift
struct ClipboardItem: Codable, Identifiable, Equatable {
    let id: UUID
    let type: ItemType          // .text | .image(旧) | .file
    var textContent: String?    // 文字内容（type == .text）

    // 旧字段（向后兼容，保留解码能力）
    var imageFileName: String?
    var originalImageName: String?
    var imageFileSize: Int?

    // 文件路径字段
    var filePaths: [String]?    // 文件绝对路径数组（type == .file）
    var fileNames: [String]?    // 文件名数组（用于显示/搜索）

    let timestamp: Date
    var isPinned: Bool

    enum ItemType: String, Codable {
        case text
        case image  // 向后兼容，迁移后不再产生
        case file
    }
}
```

## 3. 存储方案

### 元数据
- 存放位置：`UserDefaults`，key = `"clipboard_items"`
- 格式：`[ClipboardItem]` 的 JSON 编码
- 触发保存：每次新增/修改/删除操作后立即写入

### 文件记录
- **只存储路径，不保存副本**
- 点击复制时从原路径重新读取/写入剪贴板
- 源文件失效时：弹窗提示并自动删除该条记录
- 删除记录时**不删除**源文件

### 旧版图片文件（已废弃）
- 旧路径：`~/Library/Application Support/ClipboardManager/Images/`
- 首次启动时由 `migrateOldDataIfNeeded()` 清理旧图片记录与目录

## 4. 剪贴板监听方案

```
NSPasteboard.general.changeCount   // 变化计数器
每次变化时对比 count，不同则读取内容
```

- 定时器间隔：**0.5 秒**（平衡及时性和性能）
- 去重：比较内容与上一条记录是否相同
- 程序化写入后调用 `acknowledgeProgrammaticWrite()`，避免反馈回路

### 检测优先级

```
1. 文件类型（.fileURL）
   ├── 有 → 解析路径数组，过滤隐藏文件，创建 .file 记录
   └── 无 → 继续
2. 文本类型（.string，含富文本提取的纯文本）
   ├── 有且非空 → 创建 .text 记录
   └── 无或空 → 继续
3. 其他类型（含纯图片数据/截图）→ 跳过不记录
```

## 5. 模块职责

| 模块 | 文件 | 职责 |
|------|------|------|
| App 入口 | `ClistoryApp.swift` | 声明 `MenuBarExtra` + `Window` + `Settings` Scene |
| 数据模型 | `Core/ClipboardItem.swift` | 定义数据结构 |
| 存储管理 | `Core/StorageManager.swift` | `@Observable`；增删改查、持久化、过期/上限清理、旧数据迁移 |
| 剪贴板监听 | `Core/ClipboardMonitor.swift` | `@Observable`；系统剪贴板变化检测与读取 |
| 快捷键 | `Core/HotkeyManager.swift` | `@Observable`；全局快捷键注册 |
| 语言管理 | `Core/LanguageManager.swift` | 语言设置持久化、即时取词、`AppleLanguages` 覆盖与恢复 |
| 系统集成 | `App/AppDelegate.swift` | 服务启动、自动清理调度、快捷键唤起面板、窗口兜底、动态激活策略（主窗口/设置打开时 `.regular` 显示 Dock 图标与软件名，全部关闭后 `.accessory`）、监听语言变化通知刷新窗口标题等界面元素 |
| 操作服务 | `Services/ClipboardActions.swift` | 复制/置顶/删除/搜索过滤（视图共用） |
| 窗口导航 | `Services/AppWindows.swift` | 打开主窗口/设置/面板 |
| 菜单栏面板 | `UI/MenuBarPanelView.swift` | 搜索 + 列表 + 底部工具栏（主界面 / 退出） |
| 主窗口 | `UI/MainContentView.swift` | 标题栏 + 搜索 + 历史列表 + 状态栏 |
| 设置 | `UI/SettingsView.swift` | `Form` + `formStyle(.grouped)`，含语言设置 |
| 卡片组件 | `UI/Components/ClipboardItemCard.swift` | 历史记录卡片 |
| 搜索组件 | `UI/Components/SearchFieldView.swift` | 胶囊搜索框 |
| 空状态 | `UI/Components/EmptyStateView.swift` | `ContentUnavailableView` |
| 本地化资源 | `Resources/en.lproj/`、`Resources/zh-Hans.lproj/` | 各 6 张业务 `.strings` 表 + `InfoPlist.strings` |

### 设置 Key

| Key | 类型 | 说明 |
|-----|------|------|
| `retentionDays` | Int | 存储时长；**0 = 无限制**，1/5/7/30 = 保留天数；默认 1 |
| `maxItemCount` | Int | 条数上限；0 = 无上限 |
| `hotkey_combo` | Data | 全局快捷键（JSON 编码） |
| `appLanguage` | String | 语言设置：`system`（默认）/ `zh-Hans` / `en` |
| `AppleLanguages` | Array | 语言覆盖（写入应用偏好域；「跟随系统」时移除） |
| `legacy_image_migration_completed` | Bool | 旧图片数据迁移标记 |

## 6. 本地化技术方案

### 6.1 资源组织结构

```
Clistory/Clistory/Resources/
├── en.lproj/                       # 英文（CFBundleDevelopmentRegion = en）
│   ├── App.strings                 # 应用菜单与 App 层文案
│   ├── Settings.strings            # 设置页文案
│   ├── Common.strings              # 通用按钮/提示
│   ├── Main.strings                # 主窗口文案
│   ├── Panel.strings               # 菜单栏面板文案
│   ├── Components.strings          # 卡片/搜索框/空状态等组件文案
│   └── InfoPlist.strings           # CFBundleName / CFBundleDisplayName = Clistory
└── zh-Hans.lproj/                  # 简体中文
    └── （同名 6 张业务表 + InfoPlist.strings，名称 = 历史粘贴板）
```

标准 `.strings` 格式（UTF-8），键名统一为「表名小写.键」，与 `L()` 的入参一一对应。

### 6.2 取词与回退

- 全局取词函数：`L("settings.language.title")`
  - 以第一个 `.` 分割：表名小写 → 首字母大写（`settings` → `Settings.strings`），其余为键
  - 按当前生效语言从对应 `.lproj` Bundle 取词
  - 当前语言缺失时回退英文；英文仍缺失则返回键名本身（便于排查漏翻）
- `LanguageManager` 以 `Bundle.main.path(forResource: "<lang>", ofType: "lproj")` 懒加载并缓存各语言 Bundle，避免每次切语言重新加载
- 视图通过 `@Observable` 观察 `LanguageManager`，切换后即时刷新

### 6.3 语言设置与生效

- `AppLanguage`：`system` / `zh-Hans` / `en`，持久化到 `UserDefaults.standard["appLanguage"]`
- 实际生效语言由 `resolved` 决定：
  - `zh-Hans` / `en` → 直接对应 `SupportedLanguage`
  - `system` → 读取系统全局 `AppleLanguages`（`CFPreferencesCopyAppValue("AppleLanguages", kCFPreferencesAnyApplication)`），中文返回 `zh-Hans`、英文返回 `en`，未知语言回退英文
- `setLanguage(_:)` 返回实际生效语言是否变化，供设置页决定是否弹重启提示

### 6.4 AppleLanguages 覆盖与恢复

| 设置 | 写入应用偏好域 |
|------|----------------|
| 简体中文 | `AppleLanguages = ["zh-Hans"]` |
| English | `AppleLanguages = ["en"]` |
| 跟随系统 | `removeObject(forKey: "AppleLanguages")`，恢复读取系统全局值 |

- 写入的是应用偏好域（本应用 `Bundle ID` 的 UserDefaults），不影响其他应用
- 覆盖在下次启动时生效：系统级文案（应用菜单名、系统「设置…」菜单等）与 InfoPlist 应用名随之本地化
- 应用内即时切换不依赖该覆盖，直接通过 `.lproj` Bundle 取词实现

### 6.5 InfoPlist 本地化与构建配置

- `InfoPlist.strings` 本地化 `CFBundleName` / `CFBundleDisplayName`：en = `Clistory`，zh-Hans = `历史粘贴板`
- 工程配置（`Clistory/Clistory.xcodeproj/project.pbxproj`）：
  - `developmentRegion = en`
  - `knownRegions = (en, Base, "zh-Hans")`
  - `LOCALIZATION_PREFERS_STRING_CATALOGS = YES`（当前资源仍为 `.strings` 文件，不使用 `.xcstrings`）
- `CFBundleDevelopmentRegion = en`：未知语言回退英文，与 `LanguageManager` 的回退策略一致
- 应用名仅在 `InfoPlist.strings` 中维护语言差异：`Info.plist` 内 `CFBundleName` / `CFBundleDisplayName` 填英文默认值 `Clistory`，运行时由 `InfoPlist.strings` 按语言覆盖（中文显示「历史粘贴板」、英文显示「Clistory」）
- 更名不修改 Bundle ID（仍为 `com.clipboardmanager.app`），用户数据目录 `~/Library/Application Support/ClipboardManager/` 保持不变

## 7. 依赖

- 无第三方依赖，全部使用系统框架
