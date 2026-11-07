# 历史粘贴板 — 项目全景文档

> 同步于 2026-11-07，基于 v1.0.0 当前源代码与项目文档整理
> **注意**：本文档为阅读参考，不修改任何代码逻辑

---

## 一、产品概述

**历史粘贴板** 是一款 macOS 原生剪贴板管理工具，自动记录用户复制的文字和文件路径，支持搜索、置顶、删除、自动清理等功能。

- **版本**：1.0.0 (Build 1)
- **最低系统**：macOS 14 Sonoma
- **语言**：Swift 5.9+
- **UI 框架**：SwiftUI + AppKit 混合
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
lishijianqieban/
├── CLAUDE.md                          # 项目总览 + 工作约定
├── PROJECT-OVERVIEW.md                # 本文档
│
├── docs/                              # 当前产品与技术规范
│   ├── 01-requirements.md             # 产品需求文档
│   ├── 02-technical-spec.md           # 技术规范
│   └── 03-design-spec.md              # UI 设计规范
│
├── dev-logs/                          # 开发日志
│   ├── TODO.md                        # 当前待办
│   └── completed/                     # 已完成记录
│       ├── execution-plan.md          # 分阶段执行计划（已归档）
│       └── phase-01 ~ phase-08        # 8 个开发阶段
│
├── build/                             # 构建产物（git 忽略）
│
└── ClipboardManager/                  # Xcode 项目根目录
    ├── ClipboardManager.xcodeproj/    # Xcode 项目配置
    └── ClipboardManager/              # 源代码目录
        ├── ClipboardManagerApp.swift  # App 入口（@main）
        ├── Info.plist                 # 应用配置
        ├── Assets.xcassets/           # 资源目录
        ├── AppIcon.icon/              # 应用图标源文件
        ├── App/
        │   └── AppDelegate.swift      # AppKit 生命周期桥接
        ├── Core/
        │   ├── ClipboardItem.swift    # 数据模型
        │   ├── ClipboardMonitor.swift # 剪贴板监听器
        │   ├── HotkeyManager.swift    # 全局快捷键管理
        │   └── StorageManager.swift   # 持久化存储管理
        ├── Services/
        │   ├── ClipboardActions.swift # 复制/置顶/删除/搜索过滤
        │   └── AppWindows.swift       # 窗口导航
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
ClipboardManagerApp (@main)
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
│  StorageManager│ HotkeyManager                    │
│  ClipboardActions │ AppWindows                    │
├─────────────────────────────────────────────────┤
│                  App 层（生命周期）                │
│  ClipboardManagerApp (@main)                     │
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
| `AppDelegate.shared` | 菜单栏、弹出面板、主窗口管理（弱引用） |

### 3.4 动态激活策略

- `LSUIElement = true`，启动时为 `accessory`（菜单栏应用，不占 Dock）
- 主窗口 / 设置窗口打开时切换为 `.regular`（显示 Dock 图标 + 菜单栏软件名）
- 全部应用级窗口关闭后回到 `.accessory`
- 由 `AppDelegate` 监听窗口 `willClose` / `didBecomeKey` / 最小化等通知同步策略

---

## 四、各模块详细说明

### 4.1 App 入口层

#### `ClipboardManagerApp.swift` — App 入口
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
| 存储时长 | 分段选择：**1 天 / 5 天 / 7 天 / 30 天 / 无限制** + 说明 Footer |
| 存储条数 | 分段选择：10 / 20 / 50 / 100 / 200 / 无上限 |
| 快捷键 | 等宽字体展示 + 录制快捷键 + 恢复默认 |
| 启动 | 开机自动启动 Toggle（SMAppService） |
| 关于 | 应用 / 版本（读取 `CFBundleShortVersionString`）/ 简介 |

**快捷键录制**：使用 `NSEvent.addLocalMonitorForEvents` 监听键盘事件，将 AppKit 修饰键转换为 Carbon 修饰键格式。

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

---

## 六、UserDefaults 配置项

| Key | 类型 | 说明 | 默认值 |
|-----|------|------|--------|
| `clipboard_items` | Data | 剪贴板历史记录 JSON | 空数组 |
| `retentionDays` | Int | 存储天数上限（0 = 无限制） | 1 |
| `maxItemCount` | Int | 存储条数上限（0 = 无上限） | 0 |
| `hotkey_combo` | Data | 快捷键组合 JSON | Cmd+Shift+V |
| `legacy_image_migration_completed` | Bool | 旧图片数据迁移标记 | false |

---

## 七、Info.plist 关键配置

| Key | 值 | 说明 |
|-----|-----|------|
| `CFBundleName` | 历史粘贴板 | 应用名称 |
| `CFBundleShortVersionString` | `$(MARKETING_VERSION)` → 1.0.0 | 版本号（来源：项目配置） |
| `CFBundleVersion` | `$(CURRENT_PROJECT_VERSION)` → 1 | Build 号（来源：项目配置） |
| `LSMinimumSystemVersion` | 14.0 | 最低系统版本 |
| `LSUIElement` | true | 启动为菜单栏应用；运行时按窗口动态切换 `.regular` / `.accessory` |
| `CFBundleDevelopmentRegion` | zh_CN | 开发区域 |

---

## 八、技术要点总结

### 8.1 关键设计决策

1. **轮询 vs 观察者**：使用 0.5s 定时轮询 changeCount，而非 `NSPasteboard` 通知（后者不可靠）
2. **路径优先于副本**：文件/图片只记路径，轻量且始终粘贴最新内容
3. **跳过剪贴板图片数据**：截图等不再记录，从根因绕开 PNG 编码损坏问题
4. **检测优先级**：文件 → 文字 → 跳过，避免文件被误记为文字
5. **Carbon 快捷键**：使用成熟的 Carbon Event HotKey API，而非较新的方案
6. **兼容迁移**：保留旧字段解码能力，启动时一次性清理旧图片数据

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

---

## 九、快速参考

### 打开项目
```bash
open ClipboardManager/ClipboardManager.xcodeproj
```

### 构建运行
在 Xcode 中按 `Cmd+R`

### 版本号修改位置
- 唯一来源：`ClipboardManager/ClipboardManager.xcodeproj/project.pbxproj`
  - `MARKETING_VERSION`（当前 `1.0.0`）
  - `CURRENT_PROJECT_VERSION`（当前 `1`）
- `Info.plist` 通过 `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` 自动引用

### 关键文件速查

| 功能 | 文件 |
|------|------|
| App 入口 | `ClipboardManagerApp.swift` |
| 生命周期/窗口管理 | `App/AppDelegate.swift` |
| 数据模型 | `Core/ClipboardItem.swift` |
| 剪贴板监听 | `Core/ClipboardMonitor.swift` |
| 存储管理 | `Core/StorageManager.swift` |
| 快捷键 | `Core/HotkeyManager.swift` |
| 复制/置顶/删除/搜索 | `Services/ClipboardActions.swift` |
| 窗口导航 | `Services/AppWindows.swift` |
| 主窗口 UI | `UI/MainContentView.swift` |
| 菜单栏面板 UI | `UI/MenuBarPanelView.swift` |
| 设置页面 | `UI/SettingsView.swift` |
| 卡片组件 | `UI/Components/ClipboardItemCard.swift` |
| 搜索组件 | `UI/Components/SearchFieldView.swift` |
| 空状态组件 | `UI/Components/EmptyStateView.swift` |
