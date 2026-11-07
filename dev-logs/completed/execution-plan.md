# 开发执行计划（已完成归档）

> **状态**：已完成并归档。本文为首次开发阶段的分阶段执行计划，保留作开发过程记录；
> 当前实现以 [docs/01-requirements.md](../../docs/01-requirements.md)、[docs/02-technical-spec.md](../../docs/02-technical-spec.md)、[docs/03-design-spec.md](../../docs/03-design-spec.md) 为准。

## 总览

| Phase | 名称 | 预计涉及文件 | 关键产出 |
|-------|------|-------------|---------|
| 1 | 项目脚手架搭建 | 3-4 文件 | 可运行的空白 App |
| 2 | 数据层实现 | 2 文件 | 数据模型 + 存储 |
| 3 | 剪贴板监听 | 1 文件 | 自动捕获复制内容 |
| 4 | 菜单栏面板 UI | 3-4 文件 | 菜单栏弹窗可用 |
| 5 | 主窗口与设置 | 2-3 文件 | 完整设置页面 |
| 6 | 全局快捷键 | 1 文件 | Cmd+Shift+V |
| 7 | 开机自启动 | 1 文件修改 | 登录自动启动 |
| 8 | 自动清理与打磨 | 修改现有文件 | 完整体验 |

## Phase 1: 项目脚手架搭建

### 任务清单
- [ ] 使用 Xcode 创建 macOS App 项目（SwiftUI App lifecycle）
- [ ] 项目命名为 `ClipboardManager`
- [ ] 配置 Deployment Target 为 macOS 14.0
- [ ] 在 Info.plist 中添加必要权限说明
- [ ] 创建模块文件夹结构（App/、Core/、UI/）
- [ ] 占位文件：AppDelegate、空 ContentView

### 验证标准
- `open ClipboardManager.xcodeproj` 能在 Xcode 中打开
- `Cmd+R` 能成功编译运行，显示空白窗口

---

## Phase 2: 数据层实现

### 任务清单
- [ ] 创建 `ClipboardItem.swift` 数据模型
- [ ] 创建 `StorageManager.swift`
  - [ ] items 数组（内存中）
  - [ ] loadFromDisk() — 从 UserDefaults 加载
  - [ ] saveToDisk() — 写入 UserDefaults
  - [ ] addItem() — 新增记录
  - [ ] deleteItem() — 删除（含图片文件）
  - [ ] togglePin() — 切换置顶
  - [ ] getSortedItems() — 排序（置顶在前，时间降序）
  - [ ] 图片存储路径管理
- [ ] 编写简单测试代码验证功能

### 验证标准
- 在代码中写入几条测试数据，能正确读取
- 删除记录能同步删除图片文件

---

## Phase 3: 剪贴板监听

### 任务清单
- [ ] 创建 `ClipboardMonitor.swift`
- [ ] Timer 定时轮询（0.5秒）
- [ ] NSPasteboard.general.changeCount 变化检测
- [ ] 读取文字内容（string）
- [ ] 读取图片内容（TIFF → PNG 保存）
- [ ] 去重比较
- [ ] 新内容回调给 StorageManager

### 验证标准
- 在外部应用复制文字 → 应用中能看到记录
- 截图或复制图片 → 应用中能看到记录
- 连续复制相同内容 → 不会产生重复记录

---

## Phase 4: 菜单栏面板 UI

### 任务清单
- [ ] 创建 `MenuBarManager.swift`（NSStatusItem）
- [ ] 菜单栏图标（使用 SF Symbol `clipboard`）
- [ ] 创建 `MenuBarView.swift`（SwiftUI Popover 内容）
- [ ] 搜索框组件
- [ ] 列表 + 卡片组件 `ItemCardView.swift`
- [ ] 置顶/取消置顶按钮
- [ ] 删除按钮
- [ ] 点击卡片 → 写入剪贴板
- [ ] 底部工具栏（设置、退出）
- [ ] 空状态提示
- [ ] 颜色/字体应用设计规范

### 验证标准
- 点击菜单栏图标弹出面板
- 复制内容后自动出现在面板中
- 搜索、置顶、删除功能正常
- 点击记录后可在其他应用中粘贴

---

## Phase 5: 主窗口与设置页面

### 任务清单
- [ ] 创建 `MainWindowView.swift`（NavigationSplitView 布局）
- [ ] 侧边栏：历史记录 / 设置
- [ ] 历史记录页面（完整卡片视图）
- [ ] 创建 `SettingsView.swift`
  - [ ] 存储天数选择器（1/3/5 天）
  - [ ] 快捷键录制区域（UI 占位，功能在 Phase 6）
  - [ ] 开机自启开关（UI 占位，功能在 Phase 7）
- [ ] 菜单栏"设置"按钮 → 打开主窗口

### 验证标准
- 从菜单栏点击设置 → 打开主窗口
- 侧边栏切换正常
- 存储天数设置可保存和读取

---

## Phase 6: 全局快捷键

### 任务清单
- [ ] 创建 `HotkeyManager.swift`
- [ ] 使用 Carbon EventManager 注册全局热键
- [ ] 默认绑定 `Cmd+Shift+V`
- [ ] 按键触发 → 弹出菜单栏面板
- [ ] 设置页面快捷键录制功能
- [ ] 自定义快捷键持久化

### 验证标准
- 在其他应用中按 Cmd+Shift+V → 弹出面板
- 在设置中修改快捷键 → 新快捷键生效

---

## Phase 7: 开机自启动

### 任务清单
- [ ] 在设置页面接入 SMAppService
- [ ] 注册/取消 Login Item
- [ ] 开关状态同步显示
- [ ] 首次请求时向用户说明

### 验证标准
- 开启 → 系统设置中能看到该 Login Item
- 关闭 → Login Item 被移除

---

## Phase 8: 自动清理与打磨

### 任务清单
- [ ] 启动时检查过期记录并清理
- [ ] 定时器每天检查一次过期记录
- [ ] 清理时同步删除图片文件
- [ ] 清理前可选通知用户
- [ ] UI 细腻化：列表动画、卡片悬浮效果
- [ ] 空状态插图和文案
- [ ] 深色模式验证
- [ ] 应用图标（可选，先用默认）

### 验证标准
- 设置 1 天 → 超过 1 天的记录被清理
- 图片文件被同步清理
- UI 所有细节到位
