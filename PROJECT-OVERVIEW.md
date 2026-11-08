# Clistory（历史粘贴板） — 项目全景文档

> 同步于 2026-11-07，基于 v1.1 当前源代码与项目文档整理
> **注意**：本文档为阅读参考，不修改任何代码逻辑

---

## 一、产品概述

**Clistory**（中文名「历史粘贴板」）是一款 macOS 原生剪贴板管理工具，自动记录用户复制的文字和文件路径，支持搜索、置顶、删除、自动清理等功能。

- **版本**：1.1.1（Build 3）
- **最低系统**：macOS 14 Sonoma
- **语言**：Swift 5.9+
- **UI 框架**：SwiftUI + AppKit 混合
- **界面语言**：跟随系统（Follow System，默认）/ 简体中文 / English
- **第三方依赖**：无（全部系统框架）

### 记录策略

| 内容类型 | 行为 |
|---------|------|
| 纯文本 | 记录文本内容 |
| 富文本（RTF/HTML） | 提取纯文本后记录 |
| 文件/文件夹 | **只记录路径**，不保存副本 |
| 图片文件 | 与普通文件一致，记录路径 |
| 剪贴板图片数据（截图等） | **跳过不记录** |

---

## 二、项目目录结构

```
Clistory/
├── CLAUDE.md                          # 项目总览 + 工作约定
├── PROJECT-OVERVIEW.md                # 本文档
├── README.md                          # 中文版：项目介绍、安装、使用、构建
├── README_EN.md                       # 英文版 README（Clip Once. Paste Anytime.）
├── LICENSE                            # MIT
│
├── docs/                              # 当前产品与技术规范
│   ├── 01-requirements.md             # 产品需求文档
│   ├── 02-technical-spec.md           # 技术规范
│   ├── 03-design-spec.md              # UI 设计规范
│   └── images/app-icon.png            # 文档引用图标
│
├── dev-logs/                          # 开发日志
│   ├── TODO.md                        # 当前待办
│   └── completed/                     # 已完成记录
│       ├── execution-plan.md          # 分阶段执行计划（已归档）
│       └── phase-01 ~ phase-11  # 开发阶段完成记录
│
├── build/                             # 构建产物（git 忽略）
│
└── Clistory/                          # Xcode 项目根目录
    ├── Clistory.xcodeproj/            # Xcode 项目配置
    └── Clistory/                      # 源代码目录
        ├── ClistoryApp.swift          # App 入口（@main）
        ├── Info.plist                 # 应用配置
        ├── Assets.xcassets/           # 资源目录
        ├── AppIcon.icon/              # 应用图标源文件
        ├── App/
        │   └── AppDelegate.swift      # AppKit 生命周期桥接
        ├── Core/
        │   ├── ClipboardItem.swift    # 数据模型
        │   ├── ClipboardMonitor.swift # 剪贴板监听器
        │   ├── HotkeyManager.swift    # 全局快捷键管理
        │   ├── LanguageManager.swift  # 语言设置、取词与 AppleLanguages 覆盖
        │   └── StorageManager.swift   # 持久化存储管理
        ├── Services/
        │   ├── ClipboardActions.swift # 复制/置顶/删除/搜索过滤
        │   └── AppWindows.swift       # 窗口导航
        ├── Resources/                 # 本地化资源
        │   ├── en.lproj/              # 英文 .strings 表
        │   │   ├── App.strings
        │   │   ├── Settings.strings
        │   │   ├── Common.strings
        │   │   ├── Main.strings
        │   │   ├── Panel.strings
        │   │   ├── Components.strings
        │   │   └── InfoPlist.strings
        │   └── zh-Hans.lproj/         # 简体中文 .strings 表（文件名同上）
        └── UI/
            ├── MainContentView.swift  # 主窗口内容视图
            ├── MenuBarPanelView.swift # 菜单栏弹出面板视图
            ├── SettingsView.swift     # 设置页面视图
            └── Components/
                ├── ClipboardItemCard.swift # 单条记录卡片
                ├── SearchFieldView.swift   # 搜索框
                └── EmptyStateView.swift    # 空状态
```

---

## 三、应用架构

### 3.1 场景架构（SwiftUI Scene）

```
ClistoryApp (@main)
├── MenuBarExtra(.window) → MenuBarPanelView      # 菜单栏图标点击面板
├── Window(id: "main")    → MainContentView       # 主窗口（680×480）
└── Settings             → SettingsView           # 系统标准设置窗口（⌘,）
```

### 3.2 分层

```
┌─────────────────────────────────────────────────┐
│                   UI 层（SwiftUI 视图）           │
│  MainContentView │ MenuBarPanelView              │
│  SettingsView    │ ClipboardItemCard 等组件       │
├─────────────────────────────────────────────────┤
│               Core 层 + Services 层               │
│  ClipboardItem │ ClipboardMonitor                │
│  StorageManager│ HotkeyManager │ LanguageManager │
│  ClipboardActions │ AppWindows │ LegacyAppCleaner  │
├─────────────────────────────────────────────────┤
│              本地化资源（Resources）               │
│  en.lproj / zh-Hans.lproj（.strings × 6 + InfoPlist）│
├─────────────────────────────────────────────────┤
│                  App 层（生命周期）                │
│  ClistoryApp (@main)                             │
│  AppDelegate (AppKit 桥接)                       │
└─────────────────────────────────────────────────┘
```

### 3.3 单例模式

核心管理器均采用单例模式，通过 `shared` 属性访问：

| 单例 | 职责 |
|------|------|
| `StorageManager.shared` | 数据读写、持久化、过期清理、旧数据迁移 |
| `ClipboardMonitor.shared` | 系统剪贴板轮询检测 |
| `HotkeyManager.shared` | 全局快捷键注册与响应 |
| `LanguageManager.shared` | 语言设置持久化、即时取词、AppleLanguages 覆盖 |
| `AppDelegate.shared` | 菜单栏、弹出面板、主窗口管理（弱引用） |

### 3.4 动态激活策略

- `LSUIElement = true`，启动时为 `accessory`（菜单栏应用，不占 Dock）
- 主窗口 / 设置窗口打开时切换为 `.regular`（显示 Dock 图标 + 菜单栏软件名）
- 全部应用级窗口关闭后回到 `.accessory`
- 由 `AppDelegate` 监听窗口 `willClose` / `didBecomeKey` / 最小化等通知同步策略

---

## 四、各模块详细说明

### 4.1 App 入口层

#### `ClistoryApp.swift` — App 入口
- `@main` 声明应用入口，`@NSApplicationDelegateAdaptor` 桥接 `AppDelegate`
- 三个 Scene：`MenuBarExtra`（面板）、`Window(id: "main")`（主窗口 680×480）、`Settings`（设置）
- 不自定义 `.appSettings` 命令：Settings 场景自动生成唯一的「设置…」（⌘,）

#### `AppDelegate.swift` — AppKit 生命周期管理

**启动流程**（`applicationDidFinishLaunching`）：
1. 注册 `AppDelegate.shared` 弱引用
2. `registerDefaultSettings()` — 注册默认设置（`retentionDays = 1`、`maxItemCount = 0`）
3. `ClipboardMonitor.shared.startMonitoring()` — 启动剪贴板监听
4. `HotkeyManager.shared.register()` — 注册全局快捷键
5. `performStartupCleanup()` — 启动时清理过期记录 + 条数上限
6. `scheduleCleanupTimer()` — 每小时定时清理
7. `observeWindowLifecycle()` — 监听窗口生命周期，动态切换激活策略
8. 异步 `openMainWindow()` — 启动时显示主窗口
9. 延迟 1 秒后 `checkLegacyAppsAtLaunch()` — 后台检测并清理更名前遗留的旧版本应用（见 5.5）

**生命周期**：
- `applicationShouldTerminateAfterLastWindowClosed` 返回 `false`（菜单栏常驻）
- `applicationShouldHandleReopen` 点击 Dock 图标时恢复主窗口
- `applicationWillTerminate` 停止监听、注销快捷键、移除通知观察

**快捷面板（全局快捷键）**：
- `showPanel()` → `presentPanelWindow()`，使用 `NSPanel` + `NSHostingController(MenuBarPanelView())`
- 尺寸 320×480，默认定位到屏幕右上区域，失焦自动关闭

**主窗口管理**（`openMainWindow`）：
1. 升为 `.regular` 激活策略，关闭快捷面板
2. 优先前置 SwiftUI `Window` Scene 创建的窗口
3. 其次复用兜底窗口
4. 兜底：手动创建 `NSWindow` 承载 `MainContentView`

---

### 4.2 Core 核心层

#### `ClipboardItem.swift` — 数据模型

```swift
struct ClipboardItem: Codable, Identifiable, Equatable {
    let id: UUID                    // 唯一标识
    let type: ItemType              // .text | .image(旧) | .file
    var textContent: String?        // 文字内容

    // 旧字段（向后兼容，保留解码能力）
    var imageFileName: String?
    var originalImageName: String?
    var imageFileSize: Int?

    // 文件路径字段
    var filePaths: [String]?        // 文件绝对路径数组
    var fileNames: [String]?        // 文件名数组（显示/搜索）

    let timestamp: Date             // 复制时间
    var isPinned: Bool              // 是否置顶
}
```

**计算属性**：
- `formattedTime` — 智能时间描述（"刚刚"、"5分钟前"、"MM-dd HH:mm"）
- `preview` — 列表预览（文字截取 80 字符；文件显示文件名或「等N个文件」；旧图片记录兼容显示）
- `fileExtension` / `isImageFile` / `isFolder` — 用于图标与类型判断

---

#### `ClipboardMonitor.swift` — 剪贴板监听器

**工作原理**：
- 每 **0.5 秒**轮询 `NSPasteboard.general.changeCount`
- changeCount 变化时读取剪贴板内容

**内容检测优先级**：
1. **文件**（`.fileURL`）→ 解析路径数组，过滤隐藏文件（`.` 开头），创建 `.file` 记录
2. **文字**（`.string`，含富文本提取的纯文本）→ 创建 `.text` 记录
3. **其他类型（含纯图片数据/截图）→ 跳过不记录**

**防重复机制**：
- `acknowledgeProgrammaticWrite()` — 程序化写入剪贴板后调用，更新内部 changeCount
- 文字去重：与上一条记录内容比较

---

#### `StorageManager.swift` — 存储管理器

**存储方案**：

| 数据类型 | 存储位置 | 格式 |
|---------|---------|------|
| 元数据 | `UserDefaults` (key: `"clipboard_items"`) | JSON 编码的 `[ClipboardItem]` |
| 文件内容 | **不存储**（只记路径） | — |

**核心功能**：
- `addItem()` — 添加记录（插入数组头部），触发数量上限检查
- `deleteItem()` — 删除记录（旧版图片会删本地副本；文件记录只删元数据）
- `togglePin()` — 切换置顶状态
- `getSortedItems()` — 排序输出（置顶在前，时间降序）
- `cleanupExpired(retentionDays:)` — 清理过期记录（参数 ≤ 0 表示无限制；置顶项不清理）
- `enforceMaxCount()` — 执行存储条数上限
- `validateFiles(_:)` — 校验文件路径是否存在
- `migrateOldDataIfNeeded()` — 一次性清理旧图片记录与 `Images/` 目录

---

#### `HotkeyManager.swift` — 全局快捷键管理

**技术方案**：Carbon Event HotKey API

**默认快捷键**：`Cmd + Shift + V`

**快捷键数据结构**：
```swift
struct HotkeyCombo: Codable, Equatable {
    var keyCode: Int       // Carbon 虚拟键码
    var modifiers: Int     // 修饰键（cmdKey | shiftKey | ...）
}
```

**功能**：
- `register()` — 注册全局热键（InstallEventHandler + RegisterEventHotKey）
- `unregister()` — 注销热键
- `updateHotkey()` — 更新快捷键（自动保存到 UserDefaults）
- `resetToDefault()` — 恢复默认快捷键
- 按键码转可读名称（如 keyCode 9 → "V"）

**热键触发行为**：调用 `AppWindows.showPanel()` 打开快捷面板

---

#### `LanguageManager.swift` — 语言管理器

**职责**：语言设置持久化、应用内即时取词、系统级语言覆盖（供下次启动完全生效）。

**核心类型**：
- `AppLanguage` — 设置页的三个选项：`.system`（跟随系统）/ `.simplifiedChinese` / `.english`，持久化到 UserDefaults 键 `appLanguage`
- `SupportedLanguage` — 实际生效语言：`.english`（`en.lproj`）/ `.simplifiedChinese`（`zh-Hans.lproj`）
- `LanguageManager.shared` — `@Observable` 单例，持有 `setting`（持久化设置）与 `resolved`（实际生效语言）

**取词机制**：
- 全局函数 `L(_:)`，键名格式为「表名小写.键」，例如 `settings.language.title`
- 按表名懒加载对应 `.lproj` Bundle 取词；当前语言缺失时回退英文，仍缺失则返回键名
- 表名：`app` / `settings` / `common` / `main` / `panel` / `components`，对应 `Resources/<lang>.lproj/<Table>.strings`
- `locale` — 当前语言对应 Locale（`zh_Hans_CN` / `en_US`），供日期等格式化使用

**生效规则**：
- 选择「简体中文」/「English」：立即使用对应语言；「跟随系统」时读取系统全局 `AppleLanguages`（`CFPreferencesCopyAppValue` + `kCFPreferencesAnyApplication`），未知语言回退英文（与 `CFBundleDevelopmentRegion = en` 一致）
- `setLanguage(_:)` 保存设置并立即生效，返回实际生效语言是否变化；仅在变化时发送 `LanguageManagerDidChange` 通知，设置页据此弹出重启提示
- `applyLaunchLanguageOverride(for:)` 把 `AppleLanguages` 写入应用偏好域（`["zh-Hans"]` / `["en"]`），「跟随系统」时移除该覆盖；下次启动时系统级文案（应用菜单名、系统「设置…」菜单）与 InfoPlist 应用名随之本地化
- 语言切换后 AppKit 层监听 `LanguageManagerDidChange` 刷新窗口标题等界面元素（应用菜单名等系统级文案仍由下次启动生效）

---

### 4.3 Services 服务层

#### `ClipboardActions.swift` — 剪贴板操作服务
主窗口与菜单栏面板共用，避免视图层重复业务逻辑：
- `copy(_:)` — 复制到系统剪贴板，返回 `.success` 或 `.fileMissing([String])`
  - 文字：写入纯文本
  - 文件：校验路径存在后 `writeObjects` 写入文件 URL；失效返回缺失文件名
  - 旧图片记录：兜底删除
- `togglePin(_:)` / `delete(_:)` — 置顶与删除（删除不删除源文件）
- `filter(_:query:)` — 搜索过滤（文字内容 / 文件名；旧图片匹配原文件名）

#### `AppWindows.swift` — 窗口导航
- `openMain()` — 打开主窗口
- `showPanel()` — 显示快捷面板

#### `LegacyAppCleaner.swift` — 旧版本应用清理
1.1 起应用英文名由「历史粘贴板」改为「Clistory」而 Bundle ID 不变，DMG 拖拽安装后可能出现新旧两个 `.app` 共存：
- `findLegacyApps()` — 扫描 `/Applications`、`~/Applications` 中文件名为 `历史粘贴板.app` / `ClipboardManager.app` 的包，校验 Bundle ID 与当前应用一致并排除当前运行的包
- `terminateRunningApps(at:)` — 让仍在运行的旧版实例正常退出（最多等 2 秒），避免两个实例同时写历史记录
- `cleanup()` — `FileManager.trashItem` 移入废纸篓（可恢复），成功后重新注册开机自启动登录项
- 结果由 `AppDelegate` 弹窗反馈：成功提示一次；失败提供「重试 / 在访达中显示 / 稍后」

---

### 4.4 UI 视图层

#### `MainContentView.swift` — 主窗口内容

**布局**（无侧边栏，设置通过系统「设置…」⌘, 打开）：
- 顶部标题栏（应用图标 + 名称 + 记录总数）
- 搜索框（实时过滤）
- 记录列表（`LazyVStack` + `ClipboardItemCard`）
- 底部状态栏（操作提示）
- 空状态使用 `ContentUnavailableView`

**窗口尺寸**：680 × 480（可调整）

---

#### `MenuBarPanelView.swift` — 菜单栏弹出面板

**尺寸**：320 × 480

**结构**：
- 搜索框
- 内容列表（置顶分组「已置顶」+ 普通列表，带分割线）
- 底部工具栏（记录数统计 / 打开主界面 / 退出应用）

**承载方式**：`MenuBarExtra` 弹出层，或全局快捷键唤起的 `NSPanel`（失焦关闭）

---

#### `ClipboardItemCard.swift` — 单条记录卡片

**视觉元素**：
- 置顶标识线（左侧 3pt `.tint` 竖条）
- 类型图标（28×28 圆角方块 + 15% 底色，按类型/文件扩展名着色）
- 内容预览（最多 2 行）
- 悬停操作按钮（置顶 / 删除）
- 复制成功动画（绿色勾号，0.8 秒消失）
- 文件失效：SwiftUI Alert「文件已被移动或删除」→ 确定后自动删除记录

**文件图标规则**（按扩展名）：
| 类型 | 扩展名示例 | 图标 | 颜色 |
|------|-----------|------|------|
| 图片 | .png .jpg .gif .webp 等 | `photo` | 绿色 |
| PDF | .pdf | `doc.text` | 红色 |
| 文档 | .doc .docx .txt .rtf | `doc.text` | 蓝色 |
| 表格 | .xls .xlsx .csv | `tablecells` | 绿色 |
| 演示 | .ppt .pptx | `rectangle.on.rectangle` | 橙色 |
| 代码 | .swift .py .js .html .css .json | `chevron.left.forward.slash.chevron.right` | 紫色 |
| 压缩包 | .zip .rar .7z .tar .gz | `archivebox` | 灰色 |
| 文件夹 | （目录） | `folder` | 蓝色 |
| 其他 | — | `doc` | 灰色 |

---

#### `SearchFieldView.swift` — 搜索框
胶囊形，左侧放大镜，支持一键清空。

#### `EmptyStateView.swift` — 空状态
使用 `ContentUnavailableView`：
- 无记录：tray 图标 +「暂无复制记录」
- 搜索无结果：magnifyingglass 图标 +「未找到匹配内容」

#### `SettingsView.swift` — 设置页面

系统标准 `Form` + `formStyle(.grouped)`：

| Section | 控件 |
|---------|------|
| 语言 | 弹出式菜单：跟随系统（默认）/ 简体中文 / English（位于表单顶部） |
| 存储时长 | 分段选择：**1 天 / 5 天 / 7 天 / 30 天 / 无限制** + 说明 Footer |
| 存储条数 | 分段选择：10 / 20 / 50 / 100 / 200 / 无上限 |
| 快捷键 | 等宽字体展示 + 录制快捷键 + 恢复默认 |
| 启动 | 开机自动启动 Toggle（SMAppService） |
| 关于 | 应用 / 版本（读取 `CFBundleShortVersionString`）/ 简介 |

**语言切换流程**：选择语言后调用 `LanguageManager.setLanguage(_:)`；若实际生效语言变化，弹出 `NSAlert` 重启提示框（「立即重启」为默认按钮，回车触发；「稍后重启」为次按钮，Esc 触发）；选「立即重启」重启应用完全生效，选「稍后重启」则应用内界面立即切换、系统级文案留待下次启动；若实际生效语言未变化（如系统已是英文时选 English），只保存设置、不弹窗。

**快捷键录制**：使用 `NSEvent.addLocalMonitorForEvents` 监听键盘事件，将 AppKit 修饰键转换为 Carbon 修饰键格式。

---

### 4.5 本地化资源（`Resources/`）

标准 `.strings` 本地化资源，两个语言目录结构相同：

| 资源 | 用途 |
|------|------|
| `Resources/en.lproj/` | 英文界面 |
| `Resources/zh-Hans.lproj/` | 简体中文界面 |
| `App.strings` | 应用菜单名、菜单命令等 App 层文案 |
| `Settings.strings` | 设置页文案 |
| `Common.strings` | 通用按钮、通用提示（确定/取消等） |
| `Main.strings` | 主窗口文案 |
| `Panel.strings` | 菜单栏面板文案 |
| `Components.strings` | 卡片、搜索框、空状态等组件文案 |
| `InfoPlist.strings` | `CFBundleName` / `CFBundleDisplayName`：en = Clistory，zh-Hans = 历史粘贴板 |

- 键名规范：`表名小写.键`（如 `settings.language.title`）
- 构建配置：`developmentRegion = en`、`knownRegions = (en, Base, zh-Hans)`；`CFBundleDevelopmentRegion = en`，未知语言回退英文
- `LOCALIZATION_PREFERS_STRING_CATALOGS = YES`（工程级构建配置；当前资源仍为 `.strings` 文件）

---

## 五、数据流

### 5.1 剪贴板 → 存储

```
系统剪贴板变化
    ↓
ClipboardMonitor (0.5s 轮询 changeCount)
    ↓
检测内容类型（文件 → 文字 → 跳过）
    ↓
ClipboardItem 创建（.text 或 .file）
    ↓
StorageManager.addItem()
    ↓
┌─ items 数组插入头部
├─ saveToDisk() → UserDefaults JSON
└─ enforceMaxCount() → 超限清理最旧非置顶记录
```

### 5.2 用户操作 → 系统剪贴板

```
用户点击卡片 (ClipboardItemCard)
    ↓
ClipboardActions.copy(item)
    ↓
文字：NSPasteboard.setString
文件：validateFiles → writeObjects(文件 URL)
     └─ 失效 → SwiftUI Alert + 自动删除记录
    ↓
ClipboardMonitor.acknowledgeProgrammaticWrite()
    ↓
更新内部 changeCount，避免重复记录
```

### 5.3 自动清理流程

```
应用启动 → performStartupCleanup()
每小时 → scheduleCleanupTimer()
    ↓
retentionDays > 0 → cleanupExpired(retentionDays:) 清理过期记录（置顶项除外）
retentionDays = 0 → 跳过时间清理
enforceMaxCount(maxCount) → 超出上限删除最旧的非置顶记录
    ↓
deleteItem() → 仅删除元数据（旧版图片会删本地副本）
```

### 5.4 旧数据迁移（仅一次）

```
首次启动
    ↓
migrateOldDataIfNeeded()
    ↓
├─ 删除所有 type == .image 的记录及其本地副本
├─ 删除 ~/Library/Application Support/ClipboardManager/Images/
└─ 写入标记 legacy_image_migration_completed
```

### 5.5 旧版本应用清理（1.1.1+，每次启动检测）

```
启动 → 延迟 1 秒（等主窗口出现）
    ↓
LegacyAppCleaner.cleanup()（后台线程）
    ├─ 扫描 /Applications、~/Applications 中文件名为 历史粘贴板.app / ClipboardManager.app 的包
    ├─ 校验 CFBundleIdentifier == com.clipboardmanager.app，并排除当前运行的包
    ├─ 终止仍在运行的旧版实例（避免两个实例同时写历史记录）
    ├─ FileManager.trashItem → 移入废纸篓（可恢复）
    └─ 若曾开启开机自启动 → SMAppService 重新注册到新版本
    ↓
结果处理（主线程弹窗）
    ├─ 成功 → 「已清理旧版本应用」提示一次
    └─ 失败（如 App 管理权限拦截）→ 「重试 / 在访达中显示 / 稍后」；同一 Build 内只提示一次
```

### 5.6 语言切换流程

```
用户在「设置 → 语言」选择语言
    ↓
LanguageManager.setLanguage(newValue)
    ├─ 保存 setting → UserDefaults["appLanguage"]
    ├─ 写入 / 移除 AppleLanguages 覆盖（供下次启动系统级本地化）
    └─ 重新解析 resolved（跟随系统时读取全局 AppleLanguages）
    ↓
实际生效语言是否变化？
    ├─ 否 → 仅保存设置，不弹窗
    └─ 是 → 发送 LanguageManagerDidChange（应用内界面立即刷新）
           ↓
       弹出重启提示框
           ├─ 立即重启（默认，回车）→ 重启应用，全部文案切换
           └─ 稍后重启 → 应用内已切换，系统级文案下次启动生效
```

---

## 六、UserDefaults 配置项

| Key | 类型 | 说明 | 默认值 |
|-----|------|------|--------|
| `clipboard_items` | Data | 剪贴板历史记录 JSON | 空数组 |
| `retentionDays` | Int | 存储天数上限（0 = 无限制） | 1 |
| `maxItemCount` | Int | 存储条数上限（0 = 无上限） | 0 |
| `hotkey_combo` | Data | 快捷键组合 JSON | Cmd+Shift+V |
| `appLanguage` | String | 语言设置：`system` / `zh-Hans` / `en` | `system` |
| `AppleLanguages` | Array | 语言覆盖（写入应用偏好域）；「跟随系统」时移除 | 无 |
| `legacy_image_migration_completed` | Bool | 旧图片数据迁移标记 | false |
| `legacy_app_cleanup_dismissed_version` | String | 已忽略「旧版本清理失败」提示的 Build 号 | 无 |

---

## 七、Info.plist 关键配置

| Key | 值 | 说明 |
|-----|-----|------|
| `CFBundleName` | Clistory / 历史粘贴板 | 应用名称，由 `Resources/<lang>.lproj/InfoPlist.strings` 本地化 |
| `CFBundleDisplayName` | Clistory / 历史粘贴板 | 显示名称，本地化来源同上 |
| `CFBundleShortVersionString` | `$(MARKETING_VERSION)` → 1.1 | 版本号（来源：项目配置） |
| `CFBundleVersion` | `$(CURRENT_PROJECT_VERSION)` → 2 | Build 号（来源：项目配置） |
| `LSMinimumSystemVersion` | 14.0 | 最低系统版本 |
| `LSUIElement` | true | 启动为菜单栏应用；运行时按窗口动态切换 `.regular` / `.accessory` |
| `CFBundleDevelopmentRegion` | en | 开发区域；未知语言回退英文 |

---

## 八、技术要点总结

### 8.1 关键设计决策

1. **轮询 vs 观察者**：使用 0.5s 定时轮询 changeCount，而非 `NSPasteboard` 通知（后者不可靠）
2. **路径优先于副本**：文件/图片只记路径，轻量且始终粘贴最新内容
3. **跳过剪贴板图片数据**：截图等不再记录，从根因绕开 PNG 编码损坏问题
4. **检测优先级**：文件 → 文字 → 跳过，避免文件被误记为文字
5. **Carbon 快捷键**：使用成熟的 Carbon Event HotKey API，而非较新的方案
6. **兼容迁移**：保留旧字段解码能力，启动时一次性清理旧图片数据
7. **标准 .strings 本地化**：6 张业务表 + `InfoPlist.strings`，通过自建 `LanguageManager` 按 `.lproj` Bundle 取词，实现应用内即时切换
8. **AppleLanguages 覆盖**：把语言选择写入应用偏好域，让系统级文案与 InfoPlist 应用名在下次启动时本地化；「跟随系统」时移除覆盖
9. **数据零迁移更名**：Bundle ID 与数据目录保持不变，仅改产品名、工程名与产物名，老数据不丢
10. **更名迁移自动清理**：1.1.1 起启动时检测同 Bundle ID 的旧版 `历史粘贴板.app` 并移入废纸篓，同时退出旧实例、重注册登录项，避免两个 `.app` 长期共存

### 8.2 性能考量

- 剪贴板轮询间隔 0.5s（平衡及时性与 CPU 占用）
- 不保存文件副本，存储占用极低（仅元数据 JSON）
- 定时清理间隔 1 小时（非实时，减少 I/O）

### 8.3 数据安全

- 置顶项不会被自动清理
- 删除文件记录时**不删除**源文件
- 启动时和定时执行双重清理保障
- 文件失效时自动清理失效记录

### 8.4 已知局限

- 文件被移动/删除后历史记录失效（有弹窗提示 + 自动删除）
- 截图/剪贴板图片数据不进历史（产品决策）
- 文件路径可能暴露用户目录结构（暂无隐私过滤，需求明确不做）
- 全量 JSON 存 UserDefaults，文本历史极大时可考虑换存储后端
- 语言切换后系统级文案（应用菜单名、系统「设置…」菜单等）需重启应用才完全生效
- 自动清理若被 macOS「App 管理」权限拦截，需要用户手动授权或手动移入废纸篓（已提供重试/在访达中显示兜底）

---

## 九、快速参考

### 打开项目
```bash
open Clistory/Clistory.xcodeproj
```

### 构建运行
在 Xcode 中选择 `Clistory` Scheme 与 `My Mac` 目标，按 `Cmd+R`

### 命令行构建
```bash
xcodebuild -project Clistory/Clistory.xcodeproj -scheme Clistory \
  -configuration Release -derivedDataPath build/DerivedData build
```
- 产物：`build/DerivedData/Build/Products/Release/Clistory.app`
- 归档：`-archivePath build/Clistory.xcarchive`；DMG 建议 `build/Clistory-1.1.1.dmg`
- 若 `xcodebuild` 报 requires Xcode：前置 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`

### 版本号修改位置
- 唯一来源：`Clistory/Clistory.xcodeproj/project.pbxproj`
  - `MARKETING_VERSION`（当前 `1.1.1`）
  - `CURRENT_PROJECT_VERSION`（当前 `3`）
- `Info.plist` 通过 `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` 自动引用

### 关键文件速查

| 功能 | 文件 |
|------|------|
| App 入口 | `ClistoryApp.swift` |
| 生命周期/窗口管理 | `App/AppDelegate.swift` |
| 数据模型 | `Core/ClipboardItem.swift` |
| 剪贴板监听 | `Core/ClipboardMonitor.swift` |
| 存储管理 | `Core/StorageManager.swift` |
| 快捷键 | `Core/HotkeyManager.swift` |
| 语言管理 | `Core/LanguageManager.swift` |
| 本地化资源 | `Resources/en.lproj/`、`Resources/zh-Hans.lproj/` |
| 复制/置顶/删除/搜索 | `Services/ClipboardActions.swift` |
| 窗口导航 | `Services/AppWindows.swift` |
| 主窗口 UI | `UI/MainContentView.swift` |
| 菜单栏面板 UI | `UI/MenuBarPanelView.swift` |
| 设置页面 | `UI/SettingsView.swift` |
| 卡片组件 | `UI/Components/ClipboardItemCard.swift` |
| 搜索组件 | `UI/Components/SearchFieldView.swift` |
| 空状态组件 | `UI/Components/EmptyStateView.swift` |
