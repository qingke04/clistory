# CLAUDE.md — Clistory（历史粘贴板）

## 项目概述
macOS 原生历史剪贴板管理软件（英文名 **Clistory**，中文名 **历史粘贴板**，应用内名称按语言本地化）。记录文字和文件路径的复制历史，支持搜索、置顶、删除、自动清理。
提供菜单栏面板 + 独立桌面窗口两种交互方式。

- **当前版本**：1.1（Build 2）
- **Bundle ID**：`com.clipboardmanager.app`（保持不变；用户数据目录仍为 `~/Library/Application Support/ClipboardManager/`）

## 技术栈
- **语言**：Swift 5.9+
- **UI**：SwiftUI + AppKit 混合
- **存储**：UserDefaults + 文件系统
- **本地化**：标准 `.strings` 资源 + 自建 `LanguageManager`
- **最低系统**：macOS 14 (Sonoma)

## 项目文档索引

| 文档 | 路径 | 说明 |
|------|------|------|
| 产品需求 | [docs/01-requirements.md](docs/01-requirements.md) | 功能需求、用户故事、验收标准 |
| 技术规范 | [docs/02-technical-spec.md](docs/02-technical-spec.md) | 语言、框架、存储方案、数据模型、本地化方案 |
| UI设计规范 | [docs/03-design-spec.md](docs/03-design-spec.md) | SwiftUI 标准：颜色、字体、布局、组件 |
| 项目全景 | [PROJECT-OVERVIEW.md](PROJECT-OVERVIEW.md) | 架构、模块、数据流、技术要点 |
| 英文说明 | [README_EN.md](README_EN.md) | English README |

## 开发日志

| 内容 | 路径 | 说明 |
|------|------|------|
| 待办 | [dev-logs/TODO.md](dev-logs/TODO.md) | 当前待办事项清单 |
| 阶段归档 | [dev-logs/completed/](dev-logs/completed/) | 执行计划与各开发阶段的完成记录 |

## 工作约定

1. **阅读文档优先**：改动前先阅读 `docs/` 中对应规范文档
2. **小步推进**：不一次性写大量代码，每次聚焦少量文件
3. **最小可用原则**：每次改动结束应用应处于可运行状态
4. **日志同步**：完成一项工作后在 `dev-logs/` 记录，并更新 `dev-logs/TODO.md`
5. **代码风格**：Swift 代码使用标准命名约定，注释用中文（方便用户理解）
6. **界面文案本地化规范**：用户可见文案必须通过全局 `L("表名.键")` 取词（表名小写前缀：`app` / `settings` / `common` / `main` / `panel` / `components`），字符串放在 `Clistory/Clistory/Resources/<lang>.lproj/` 下；新增语言时在 `Resources/<lang>.lproj/` 增加同名 `.strings` 表，并同步工程 `knownRegions` 与 InfoPlist 本地化；禁止在 Swift 代码中硬编码界面中文；注释仍用中文

## 项目目录结构

```
.
├── CLAUDE.md
├── README.md                       # 中文版：项目介绍、安装、使用、构建与许可证
├── README_EN.md                    # 英文版 README（Clip Once. Paste Anytime.）
├── LICENSE                         # MIT
├── PROJECT-OVERVIEW.md
├── docs/
│   ├── 01-requirements.md
│   ├── 02-technical-spec.md
│   ├── 03-design-spec.md
│   └── images/
├── dev-logs/
│   ├── TODO.md
│   └── completed/
│       ├── execution-plan.md        # 分阶段执行计划（已归档）
│       └── phase-01 ~ phase-11  # 阶段完成记录
└── Clistory/                        # Xcode 项目
    ├── Clistory.xcodeproj/
    └── Clistory/
        ├── ClistoryApp.swift
        ├── Info.plist
        ├── Assets.xcassets/
        ├── AppIcon.icon/
        ├── App/                     # AppDelegate 系统集成
        ├── Core/                    # 数据模型、存储、监听、快捷键、语言管理
        ├── Services/                # ClipboardActions、AppWindows
        ├── Resources/               # en.lproj / zh-Hans.lproj 本地化字符串
        └── UI/                      # SwiftUI 界面 + Components
```

## 版本管理

- 当前版本：**1.1（Build 2）**，不再维护历史版本号与版本更新日志
- 版本号唯一来源：`Clistory/Clistory.xcodeproj/project.pbxproj`
  - `MARKETING_VERSION` = `1.1`
  - `CURRENT_PROJECT_VERSION` = `2`
- `Info.plist` 通过 `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` 引用上述配置，无需单独修改

## 快速命令参考

- 打开 Xcode 项目：`open Clistory/Clistory.xcodeproj`
- 构建运行：在 Xcode 中选择 `Clistory` Scheme 与 `My Mac` 目标，按 `Cmd+R`
- 命令行构建：
  ```bash
  xcodebuild -project Clistory/Clistory.xcodeproj -scheme Clistory -configuration Release -derivedDataPath build/DerivedData build
  ```
  - 产物：`build/DerivedData/Build/Products/Release/Clistory.app`
- 归档分发：
  ```bash
  xcodebuild -project Clistory/Clistory.xcodeproj -scheme Clistory -configuration Release -archivePath build/Clistory.xcarchive archive
  ```
  - 归档产物：`build/Clistory.xcarchive/Products/Applications/Clistory.app`；DMG 建议 `build/Clistory-1.1.dmg`
- 若 `xcodebuild` 报 requires Xcode（本机 active developer directory 为 CommandLineTools）：命令前加 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`
