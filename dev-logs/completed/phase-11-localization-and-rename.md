# Phase 11 完成记录 — 语言设置与改名 Clistory

**完成时间**：2026-11-07
**状态**：✅ 完成（1.1 Release 构建、双语言冒烟测试、DMG 打包、GitHub 发布均已验证）

## 背景

1.0.0 的应用名固定为「历史粘贴板」，界面文案全部为中文硬编码，不面向英文用户。本次改动同时完成两件事：

- **新增语言设置**：支持跟随系统（Follow System）/ 简体中文 / English，应用内文案即时切换，系统级文案重启后完全生效。
- **软件改名**：英文名定为 **Clistory**，中文名保持 **历史粘贴板**；应用内名称按语言本地化，工程、target、scheme 与构建产物统一为 Clistory。

改名的前提是**用户数据不迁移**：Bundle ID 仍为 `com.clipboardmanager.app`，用户数据目录仍为 `~/Library/Application Support/ClipboardManager/`，老数据不会丢失。

## 产出

### 1. 重命名

- Xcode 工程：原 `ClipboardManager.xcodeproj` → `Clistory/Clistory.xcodeproj`
- target / scheme / 构建产物：`Clistory` / `Clistory.app`
- 源目录与入口文件：`Clistory/Clistory/`、`Clistory/Clistory/ClistoryApp.swift`
- 应用内名称本地化（`Resources/<lang>.lproj/InfoPlist.strings`）：
  - en：`CFBundleName` / `CFBundleDisplayName` = `Clistory`
  - zh-Hans：`CFBundleName` / `CFBundleDisplayName` = `历史粘贴板`
- **不变项**：Bundle ID `com.clipboardmanager.app`、用户数据目录 `~/Library/Application Support/ClipboardManager/`、Git 历史、GitHub 远程仓库

### 2. 版本号

- `MARKETING_VERSION = 1.1`
- `CURRENT_PROJECT_VERSION = 2`
- 展示版本：**1.1（Build 2）**
- 唯一来源：`Clistory/Clistory.xcodeproj/project.pbxproj`；`Info.plist` 仍通过 `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` 引用

### 3. 本地化架构

- 新增 `Core/LanguageManager.swift`（`@Observable` 单例）：
  - `AppLanguage`：设置项 `system` / `zh-Hans` / `en`，持久化到 UserDefaults 键 `appLanguage`
  - `SupportedLanguage`：实际生效语言 `en` / `zh-Hans`，分别对应 `en.lproj` / `zh-Hans.lproj`
  - `resolved`：当前生效语言；`system` 时读取系统全局 `AppleLanguages`（`CFPreferencesCopyAppValue` + `kCFPreferencesAnyApplication`），中文取 `zh-Hans`、英文取 `en`，未知语言回退英文（与 `CFBundleDevelopmentRegion = en` 一致）
  - 全局取词函数 `L("表名小写.键")`（如 `settings.language.title`）：按表名懒加载并缓存对应 `.lproj` Bundle 取词；当前语言缺失时回退英文，仍缺失返回键名
  - `setLanguage(_:)`：保存设置并立即生效，返回实际生效语言是否变化；变化时发送 `LanguageManagerDidChange` 通知
  - `AppleLanguages` 覆盖：简体中文写 `["zh-Hans"]`、English 写 `["en"]`、跟随系统时移除覆盖，写入的是本应用偏好域，供下次启动时系统级文案与 InfoPlist 应用名本地化
- InfoPlist 本地化：`Resources/en.lproj/InfoPlist.strings`、`Resources/zh-Hans.lproj/InfoPlist.strings`
- 构建配置：`developmentRegion = en`、`knownRegions = (en, Base, "zh-Hans")`、`LOCALIZATION_PREFERS_STRING_CATALOGS = YES`（资源仍为标准 `.strings` 文件）

### 4. 设置页与重启流程

- 设置表单顶部新增「语言」分区（`SettingsView`）：弹出式菜单，选项为「跟随系统（Follow System，默认）」「简体中文」「English」
- 切换后调用 `LanguageManager.setLanguage(_:)`：
  - 实际生效语言发生变化 → 应用内文案立即切换，并弹出重启提示框
    - **立即重启**：默认选中，回车触发；重启应用，应用内与系统级文案全部切换
    - **稍后重启**：关闭弹窗；应用内已切换，系统级文案（应用菜单名、系统「设置…」菜单等）下次启动后完全切换
  - 实际生效语言未变化（如系统已是英文时选 English）→ 只保存设置，不弹窗

### 5. 本地化资源文件

位于 `Clistory/Clistory/Resources/{en.lproj,zh-Hans.lproj}/`，两种语言各 7 个文件：

| 文件 | 用途 |
|------|------|
| `App.strings` | 应用菜单与 App 层文案 |
| `Settings.strings` | 设置页文案 |
| `Common.strings` | 通用按钮/提示 |
| `Main.strings` | 主窗口文案 |
| `Panel.strings` | 菜单栏面板文案 |
| `Components.strings` | 卡片、搜索框、空状态等组件文案 |
| `InfoPlist.strings` | 应用显示名称 |

键名统一为「表名小写.键」，与 `L()` 入参一一对应。

### 6. 文档同步

- `README.md`：双语名称、1.1（Build 2）、DMG 下载名与 `Clistory.app`、语言设置使用说明、源码构建/项目结构新路径、数据目录不变
- `README_EN.md`：英文版 README，简介为 *Clip Once. Paste Anytime.*；与中文 README 顶部互链，并在文档索引/项目结构中登记
- `PROJECT-OVERVIEW.md`：名称、版本、目录结构、架构图与模块表（新增 `LanguageManager` 与 Resources）、语言切换数据流、UserDefaults 与 Info.plist 配置
- `CLAUDE.md`：项目概述、版本、目录结构、快速命令、界面文案本地化规范
- `docs/01-requirements.md`：语言设置需求与验收标准
- `docs/02-technical-spec.md`：本地化技术方案（资源表、取词与回退、AppleLanguages 覆盖/恢复、InfoPlist、构建配置）
- `docs/03-design-spec.md`：设置页语言分区与重启提示框 UI 规格
- `dev-logs/TODO.md`：更新当前版本，新增 1.1 清单，保留 1.0.0 历史记录

## 验证方式（已执行）

由 Lead 执行，验证结果见下方「验证结果」：

1. 构建：
   ```bash
   xcodebuild -project Clistory/Clistory.xcodeproj -scheme Clistory \
     -configuration Release -derivedDataPath build/DerivedData build
   ```
   产物：`build/DerivedData/Build/Products/Release/Clistory.app`
2. 启动后进入「设置 → 语言」，依次验证：
   - 默认「跟随系统」：系统为简体中文时界面为中文，其他语言回退英文
   - 切到「简体中文」/「English」：应用内文案立即切换
   - 实际生效语言变化时弹出重启提示框，默认按钮为「立即重启」，回车可触发
   - 选「立即重启」：重启后应用内与系统级文案均为新语言
   - 选「稍后重启」：应用内已切换，重启后系统级文案完全切换
   - 系统已是英文时选 English：只保存设置、不弹窗
   - 英文界面应用名显示 Clistory，中文界面显示历史粘贴板
3. 数据兼容：从 1.0.0 升级后历史记录仍在（Bundle ID 与数据目录未变）
4. 打包 DMG：`build/Clistory-1.1.dmg`，安装到「应用程序」后再次验收

## 验证结果

- **构建**：`xcodebuild` Release 通用构建通过（`arm64 + x86_64`，Xcode 27.2），产物 `build/DerivedData/Build/Products/Release/Clistory.app`
- **版本**：`CFBundleShortVersionString = 1.1`、`CFBundleVersion = 2`、`CFBundleDevelopmentRegion = en`
- **资源**：App 包内 `en.lproj` / `zh-Hans.lproj` 各含 7 个 `.strings` 文件（6 张业务表 + InfoPlist）
- **中文（跟随系统）**：菜单栏应用名为「历史粘贴板」，窗口标题、条数、搜索占位、底部提示均为中文
- **英文（`AppleLanguages` 覆盖后重启）**：菜单栏应用名为「Clistory」，系统菜单为 Edit/View/Window/Help，界面文案为英文
- **即时切换（模拟「稍后重启」）**：以英文启动后在运行中切换为简体中文，窗口标题与全部界面文案立即变为中文，而菜单栏应用名仍保持 Clistory（系统级文案待重启），与设计一致
- **数据兼容**：启动 1.1 构建后仍读取到 1.0.0 时期的 4 条历史记录（Bundle ID 与数据目录未变）
- **DMG**：`build/Clistory-1.1.dmg`（2.5 MB），`hdiutil verify` 校验 VALID，SHA-256 `e93a10f899de0e0b1ce01cf72016fe0ea4da6e4385cbee6674a6cd0d88e3cb07`
- **GitHub 发布**：tag `v1.1`、Release「Clistory v1.1」与附件 `Clistory-1.1.dmg` 创建成功；从 Release 下载回验的 SHA-256 与本地一致；Release 说明包含「添加英语」「项目名称改成 Clistory」两项更新日志（中英双语）
- 说明：设置页选择器的人工点击流程因本机未授予终端辅助功能权限而未做 UI 自动化；「即时切换」通过运行时环境变量触发同一 `setLanguage(_:)` 路径完成验证

## 影响与注意事项

- **数据不迁移**：Bundle ID `com.clipboardmanager.app` 与用户数据目录 `~/Library/Application Support/ClipboardManager/` 均未改变，1.0.0 的历史记录可直接沿用
- **GitHub 已提交并发布**：提交 `8e3c2a0` 已推送 `main`，创建 tag `v1.1` 与 Release「Clistory v1.1」（<https://github.com/qingke04/clipboard-history/releases/tag/v1.1>）；仓库名仍为 `clipboard-history`，Git 历史保留
- **系统级文案需重启**：语言设置只对应用内文案即时生效，应用菜单名、系统「设置…」菜单等由 `AppleLanguages` 覆盖在下次启动时生效；实际生效语言无变化时不弹窗
- **未完成项**：DMG 安装到「应用程序」的人工验收
- 新增语言时：在 `Resources/<lang>.lproj/` 增加同名 `.strings` 表，并同步工程 `knownRegions`、InfoPlist 本地化与 `LanguageManager` 的语言解析规则
