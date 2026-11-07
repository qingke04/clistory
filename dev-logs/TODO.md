# 待办事项

> 最后更新：2026-11-07
> 当前版本：1.0.0 (Build 1)

## 当前状态：1.0.0 已发布到 GitHub（含 DMG Release），待安装验收

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
- [x] 新建公开仓库 <https://github.com/qingke04/clipboard-history>，推送 `main`
- [x] 创建 Release v1.0.0，上传 `build/历史粘贴板-1.0.0.dmg`

## 构建产物

| 项目 | 值 |
|------|----|
| 安装包 | `build/历史粘贴板-1.0.0.dmg`（2.5 MB） |
| 下载地址 | <https://github.com/qingke04/clipboard-history/releases/latest> |
| 版本 | 1.0.0 (Build 1) |
| 架构 | universal（arm64 + x86_64） |
| 签名 | ad-hoc（无开发者证书） |
| SHA-256 | `26c4263fab6b0824f783a4fda27c3eda8f5eb437364bf6d055ce88765f0c1ca0` |

> ad-hoc 签名未公证：首次在其他 Mac 打开时，可能需右键「打开」或在「系统设置 → 隐私与安全性」中放行。

## 已知问题

- [ ] MenuBarExtra 右键菜单不可用（SwiftUI 标准限制）——设置/退出已放在应用菜单与面板底部工具栏

## 后续可扩展项

- [ ] 导出/导入历史
- [ ] 深色模式专项优化
- [ ] 补充 StorageManager 单元测试（增删、上限、过期、迁移、无限制）
- [ ] 隐私加固（可选：路径脱敏显示、敏感应用/路径黑名单）
- [ ] 评估是否恢复截图历史（可选开关 + 临时目录方案）
