# Phase 12 完成记录 — 旧版本应用自动清理（修复更名后两个 .app 共存）

**完成时间**：2026-11-08
**状态**：✅ 代码、构建、DMG 与端到端迁移验证完成（待提交/发布）

## 背景

1.1 起应用英文名由「历史粘贴板」改为 **Clistory**，产物名从 `历史粘贴板.app` 变为 `Clistory.app`，但 Bundle ID 始终保持 `com.clipboardmanager.app`。

DMG 采用拖拽安装：包文件名不同就不会覆盖，于是从 1.0.x 升级后「应用程序」文件夹里会同时存在：

- `历史粘贴板.app`（旧版 1.0.x）
- `Clistory.app`（新版）

更麻烦的是中文系统下 `InfoPlist.strings` 会把 `Clistory.app` 本地化显示为「历史粘贴板」，Finder 中两个应用**显示名完全相同**，用户很难分辨该删哪个。此前 README 只能让用户手动删除旧版，体验差且容易残留。

## 方案

新版启动时自动检测并清理旧版本（一次性迁移），不依赖用户手动操作：

1. **检测**（`Services/LegacyAppCleaner.swift`）
   - 扫描 `/Applications`、`~/Applications` 顶层，只看磁盘文件名为 `历史粘贴板.app` / `ClipboardManager.app` 的包
   - 校验包内 `CFBundleIdentifier` 与当前应用一致、并排除当前正在运行的包，避免误删同名但无关的应用
   - 不依赖 Finder 显示名（会随语言本地化）
2. **清理**
   - 先让仍在运行的旧版实例 `terminate()`（最多等 2 秒），避免两个菜单栏实例同时写同一份历史记录
   - `FileManager.trashItem` 移入废纸篓（可恢复，不直接 `rm`）
   - 若先前开启过「开机自动启动」，重新注册 `SMAppService` 登录项使其指向新版本
3. **反馈**（`AppDelegate`）
   - 启动后延迟 1 秒（等主窗口出现）在后台执行，主线程弹窗
   - 成功：提示「已清理旧版本应用」一次（旧包已不存在，后续启动不会重复）
   - 失败（如 macOS「App 管理」权限拦截）：提供「重试 / 在访达中显示 / 稍后」；同一 Build 内失败提示只出现一次，避免每次启动打扰
   - 无旧版本：不弹窗、不打扰
4. **文案**：中英文加入 `Resources/{en,zh-Hans}.lproj/App.strings`（`app.legacyApp.*`），走现有 `L()` 取词规范

## 改动文件

| 文件 | 改动 |
|------|------|
| `Clistory/Clistory/Services/LegacyAppCleaner.swift` | 新增：旧版本扫描、退出旧实例、移入废纸篓、重注册登录项 |
| `Clistory/Clistory/App/AppDelegate.swift` | 启动后调用清理、成功/失败弹窗与重试逻辑 |
| `Clistory/Clistory/Resources/{en,zh-Hans}.lproj/App.strings` | 新增 `app.legacyApp.*` 中英文文案 |
| `Clistory/Clistory.xcodeproj/project.pbxproj` | 登记新文件；`MARKETING_VERSION = 1.1.1`、`CURRENT_PROJECT_VERSION = 3` |
| `README.md` / `README_EN.md` | 从 1.0.0 升级步骤改为「自动清理 + 权限兜底」，下载包名改为 `Clistory-1.1.1.dmg` |
| `CLAUDE.md` / `PROJECT-OVERVIEW.md` | 版本、模块说明、数据流 5.5、UserDefaults 键、技术要点 |
| `docs/01-requirements.md` / `docs/02-technical-spec.md` | 新增升级清理需求/验收标准与实现说明 |
| `dev-logs/TODO.md` | 1.1.1 清单、构建产物与 SHA-256 |

## 验证结果

- **构建**：`xcodebuild` Release 通用构建通过（`arm64 + x86_64`），`MARKETING_VERSION = 1.1.1`、`CURRENT_PROJECT_VERSION = 3`
- **端到端迁移测试**（真实环境，共两轮）：
  1. 从 `build/历史粘贴板-1.0.0.dmg` 取出 `历史粘贴板.app`，用 `ditto` 复制进 `/Applications`，制造「新旧两个 .app 共存」现场
  2. 运行新构建的 `Clistory.app`
  3. 结果：`/Applications` 中旧包消失，`stat ~/.Trash/历史粘贴板.app` 可见（已移入废纸篓，可恢复）；系统日志出现 `kTCCServiceSystemPolicyAppBundles` 预检但未阻断
  4. 第二轮额外先直接启动 1.0.0 旧版实例，再启动新版：旧实例被正常退出（进程消失），随后旧包移入废纸篓
  5. 测试残留已从废纸篓删除，`/Applications` 恢复为仅 `Clistory.app`，用户偏好文件未被测试实例写入
- **DMG**：`build/Clistory-1.1.1.dmg`（2.6 MB），`hdiutil verify` 校验 VALID；挂载后包内版本为 1.1.1（Build 3），含新文案，通用架构；SHA-256 `d98b0c2e341bc4c675a0237c719a9b9ccdad37b9fa5906a8a12a15f226509885`

## 注意事项

- **已安装 1.1 的用户不会自动获得修复**：必须安装 1.1.1 才会执行清理
- **旧版正在运行时**：实测 macOS 26 上按 Finder 路径启动新版会启动独立实例（同 Bundle ID 也不同路径），清理时退出旧实例后移入废纸篓；若个别系统只激活旧实例，从菜单栏退出旧版后重新启动新版即可
- **App 管理权限**：macOS 13+ 的 `kTCCServiceSystemPolicyAppBundles` 可能拦截对其它应用的移动操作；失败时弹窗引导到「系统设置 → 隐私与安全性 → App 管理」授权后重试，或手动移入废纸篓
- **未做**：GitHub 提交/Release、Homebrew `clistory` cask 的 `version`/`sha256` 更新（见 `dev-logs/TODO.md` 待办）
- **数据不变**：Bundle ID 与用户数据目录未改，历史记录不受影响
