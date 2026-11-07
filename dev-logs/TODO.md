# 待办事项

> 最后更新：2026-11-08
> 当前版本：1.1（Build 2）

## 当前状态：1.1 已发布到 GitHub（tag `v1.1` + Release + `Clistory-1.1.dmg`，含英文版 README）；Homebrew Tap 与 `clistory` cask 已重建并实测；待安装验收

### 1.1 语言设置 + 重命名

- [x] 软件改名：英文名 **Clistory**，中文名保持 **历史粘贴板**；应用内名称按语言本地化（`InfoPlist.strings`：en = Clistory，zh-Hans = 历史粘贴板）
- [x] Xcode 工程 / target / scheme / 产物名从 ClipboardManager 改为 Clistory；源目录与入口文件改为 `Clistory/Clistory`、`ClistoryApp.swift`
- [x] 版本号更新为 **1.1（Build 2）**，唯一来源 `Clistory/Clistory.xcodeproj/project.pbxproj`
- [x] 新增设置 →「语言」：跟随系统（Follow System，默认）/ 简体中文 / English
- [x] 新增 `Core/LanguageManager.swift`：`.lproj` 取词、应用内即时切换、`AppleLanguages` 覆盖与恢复、未知语言回退英文
- [x] 新增 6 张业务 `.strings` 表（App/Settings/Common/Main/Panel/Components）+ `InfoPlist.strings`，位于 `Resources/{en.lproj,zh-Hans.lproj}/`
- [x] 重启提示框：「立即重启」（默认选中，回车触发）与「稍后重启」；实际生效语言无变化时只保存设置、不弹窗
- [x] 文档同步：README / PROJECT-OVERVIEW / CLAUDE.md / docs/01~03 / dev-logs
- [x] 新增英文版 README `README_EN.md`（简介 *Clip Once. Paste Anytime.*），中英文 README 互链
- [x] 按 1.1 重建 Homebrew Tap（cask 名 `clistory`）以及主仓库 README 说明；本机 tap / 安装 / 卸载 / 升级链路实测通过（详见 `phase-10`）
- [ ] 后续发版时同步更新 `clistory` cask 的 `version` 与 `sha256`（DMG 保持 `Clistory-<version>.dmg`，tag 保持 `v<version>`）
- [x] 构建验证：`xcodebuild` Release 通用构建通过（arm64 + x86_64，Xcode 27.2）；中文/英文启动与「即时切换」冒烟测试通过（详见 `phase-11`）
- [x] 打包 DMG：`build/Clistory-1.1.dmg`（2.5 MB，`hdiutil verify` 校验通过）
- [ ] 安装 DMG 验收（应用名本地化、语言切换、重启提示、无变化不弹窗）
- [x] GitHub 提交并推送 `main`（提交 `8e3c2a0`）
- [x] 创建 Release v1.1（tag `v1.1`），上传 `Clistory-1.1.dmg`，Release 说明含「添加英语」「项目名称改成 Clistory」两项更新日志
  - Release: <https://github.com/qingke04/clistory/releases/tag/v1.1>
  - 已下载回验：上传 DMG 的 SHA-256 与本地一致

## 历史记录（1.0.0）

### 发布前检查

- [x] 版本号统一为 1.0.0（Xcode 项目配置 + Info.plist 引用）
- [x] 清理历史版本号与版本更新日志
- [x] Release 通用构建（arm64 + x86_64），ad-hoc 签名，签名与版本校验通过
- [x] 打包 DMG：`build/历史粘贴板-1.0.0.dmg`
- [ ] 安装 DMG 到「应用程序」并启动验收
- [ ] 验证功能测试要点（见 `docs/01-requirements.md`、`docs/03-design-spec.md`）
- [ ] 验证动态激活策略（主窗口/设置打开时显示 Dock 图标与软件名，关闭后收回）

### GitHub 发布

- [x] 仓库整理：新增 `README.md`（安装/使用/隐私/构建/文档索引/已知限制）与 `LICENSE`（MIT）
- [x] 新建公开仓库 <https://github.com/qingke04/clistory>，推送 `main`
- [x] 创建 Release v1.0.0，上传 `build/历史粘贴板-1.0.0.dmg`

## 构建产物

| 项目 | 值 |
|------|----|
| 1.1 安装包 | `build/Clistory-1.1.dmg`（2.5 MB） |
| 1.0.0 安装包（历史） | `build/历史粘贴板-1.0.0.dmg`（2.5 MB） |
| 发布地址 | <https://github.com/qingke04/clistory/releases/tag/v1.1>（最新 Release） |
| Homebrew | Tap <https://github.com/qingke04/homebrew-tap>，命令 `brew install --cask qingke04/tap/clistory` |
| 当前版本 | 1.1（Build 2）（GitHub 已发布） |
| 架构 | universal（arm64 + x86_64） |
| 签名 | ad-hoc（无开发者证书） |
| 1.0.0 SHA-256 | `26c4263fab6b0824f783a4fda27c3eda8f5eb437364bf6d055ce88765f0c1ca0` |
| 1.1 SHA-256 | `e93a10f899de0e0b1ce01cf72016fe0ea4da6e4385cbee6674a6cd0d88e3cb07` |

> ad-hoc 签名未公证：首次在其他 Mac 打开时，可能需右键「打开」或在「系统设置 → 隐私与安全性」中放行。

## 已知问题

- [ ] MenuBarExtra 右键菜单不可用（SwiftUI 标准限制）——设置/退出已放在应用菜单与面板底部工具栏
- [ ] 语言切换后系统级文案（应用菜单名、系统「设置…」菜单等）需重启应用才完全生效（设计预期，非缺陷）

## 后续可扩展项

- [ ] Apple Developer Program 签名 + 公证

- [ ] 导出/导入历史
- [ ] 深色模式专项优化
- [ ] 补充 StorageManager 单元测试（增删、上限、过期、迁移、无限制）
- [ ] 隐私加固（可选：路径脱敏显示、敏感应用/路径黑名单）
- [ ] 评估是否恢复截图历史（可选开关 + 临时目录方案）
