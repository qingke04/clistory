# 02 — 技术规范

> 本文档描述当前实现（SwiftUI 标准 UI 架构），适用于 v1.0.0。

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
| App 入口 | `ClipboardManagerApp.swift` | 声明 `MenuBarExtra` + `Window` + `Settings` Scene |
| 数据模型 | `Core/ClipboardItem.swift` | 定义数据结构 |
| 存储管理 | `Core/StorageManager.swift` | `@Observable`；增删改查、持久化、过期/上限清理、旧数据迁移 |
| 剪贴板监听 | `Core/ClipboardMonitor.swift` | `@Observable`；系统剪贴板变化检测与读取 |
| 快捷键 | `Core/HotkeyManager.swift` | `@Observable`；全局快捷键注册 |
| 系统集成 | `App/AppDelegate.swift` | 服务启动、自动清理调度、快捷键唤起面板、窗口兜底、动态激活策略（主窗口/设置打开时 `.regular` 显示 Dock 图标与软件名，全部关闭后 `.accessory`） |
| 操作服务 | `Services/ClipboardActions.swift` | 复制/置顶/删除/搜索过滤（视图共用） |
| 窗口导航 | `Services/AppWindows.swift` | 打开主窗口/设置/面板 |
| 菜单栏面板 | `UI/MenuBarPanelView.swift` | 搜索 + 列表 + 底部工具栏（主界面 / 退出） |
| 主窗口 | `UI/MainContentView.swift` | 标题栏 + 搜索 + 历史列表 + 状态栏 |
| 设置 | `UI/SettingsView.swift` | `Form` + `formStyle(.grouped)` |
| 卡片组件 | `UI/Components/ClipboardItemCard.swift` | 历史记录卡片 |
| 搜索组件 | `UI/Components/SearchFieldView.swift` | 胶囊搜索框 |
| 空状态 | `UI/Components/EmptyStateView.swift` | `ContentUnavailableView` |

### 设置 Key

| Key | 类型 | 说明 |
|-----|------|------|
| `retentionDays` | Int | 存储时长；**0 = 无限制**，1/5/7/30 = 保留天数；默认 1 |
| `maxItemCount` | Int | 条数上限；0 = 无上限 |
| `hotkey_combo` | Data | 全局快捷键（JSON 编码） |
| `legacy_image_migration_completed` | Bool | 旧图片数据迁移标记 |

## 6. 依赖

- 无第三方依赖，全部使用系统框架
