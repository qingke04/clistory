# Phase 10 完成记录 — Homebrew 安装方式（Clistory 1.1 重建）

**完成时间**：2026-11-08
**状态**：✅ 完成

## 目标

用 1.1 版本按原有方式重新提供 Homebrew 命令安装：重建 `qingke04/homebrew-tap` 仓库与 cask，并适配新的应用名 `Clistory.app` 与安装包名 `Clistory-<version>.dmg`。

## 产出

### Tap 仓库

- 公开仓库：<https://github.com/qingke04/homebrew-tap>
- `Casks/clistory.rb`：cask 定义
  - cask 名：`clistory`（安装命令 `brew install --cask qingke04/tap/clistory`）
  - 版本 `1.1`，SHA-256 `e93a10f899de0e0b1ce01cf72016fe0ea4da6e4385cbee6674a6cd0d88e3cb07`
  - 下载地址：`https://github.com/qingke04/clipboard-history/releases/download/v#{version}/Clistory-#{version}.dmg`
  - `app "Clistory.app"`、`uninstall quit: "com.clipboardmanager.app"`、`zap trash:`、`livecheck :github_latest`、`depends_on macos: :sonoma`
  - `caveats`：说明 ad-hoc 签名未公证时的首次启动放行方式
- `README.md`：安装 / 更新 / 卸载、首次启动说明、维护者发版流程

### 主仓库

- `README.md` / `README_EN.md`：恢复「使用 Homebrew（推荐）」安装、升级、卸载说明，以及 Homebrew 版本首次启动的 Gatekeeper 提示
- `dev-logs/TODO.md`：更新 Homebrew 安装清单与发版维护项

## 验证

本机 Homebrew 7.0.12 实测：

- `brew tap qingke04/tap` 成功（本机 GitHub 访问经本地代理）
- `brew install --cask qingke04/tap/clistory`：自动 tap、自动信任该 cask，下载并校验 SHA-256 通过
- 临时 appdir（`--appdir`）安装 / 卸载通过，产物 `Clistory.app` 版本 1.1（arm64 + x86_64），en/zh-Hans 本地化资源齐全
- 正式安装到 `/Applications/Clistory.app`（同版本已存在时用 `--force` 接管）成功，`brew list --cask` 显示 `clistory`
- `brew upgrade --cask clistory` 检查正常（当前已是最新 1.1）
- 启动应用正常

## 注意事项

- cask 名从旧的 `clipboard-history` 改为 `clistory`；旧 Tap 提供的 `clipboard-history` cask 已下线，历史安装过旧 cask 的用户需先 `brew uninstall --cask clipboard-history` 再安装 `clistory`
- 发版时 cask 需同步更新 `version` 与 `sha256`；DMG 命名保持 `Clistory-<version>.dmg`、tag 保持 `v<version>`，否则 cask URL 无法拼接
- 安装包为 ad-hoc 签名、未公证，首次启动仍需 Gatekeeper 放行
