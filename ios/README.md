# 四象 Sixiang · iOS 客户端

SwiftUI（iOS 17+）+ SwiftData（离线优先）+ WidgetKit。工程由 **XcodeGen** 生成（`project.yml` 是唯一工程真源，`*.xcodeproj` 不入库）。

## 构建

需要 macOS + Xcode 15+（iOS 17 SDK）：

```bash
cd ios
brew install xcodegen      # 首次
xcodegen generate          # 生成 Sixiang.xcodeproj
open Sixiang.xcodeproj     # Xcode 中运行
```

**无 Mac 环境**：推送到 GitHub 后由 Actions 自动构建验证（`.github/workflows/ios-build.yml`，macOS runner + 模拟器目标、免签名）。构建产物如需真机安装，需在 Xcode 中配置你自己的签名团队。

## 真机运行 / 分发签名

1. `ios/project.yml` 中把 `bundleIdPrefix` 改为你自己的前缀，或直接改两个 target 的 `PRODUCT_BUNDLE_IDENTIFIER`（App：`app.sixiang.workbench`，Widget：`app.sixiang.workbench.widget`）
2. `App/Sixiang.entitlements` 与 `Widget/SixiangWidget.entitlements` 中把 App Group `group.app.sixiang.workbench` 换成你签名团队可用的 group（需在 Apple Developer 后台登记）
3. 同步修改 `Shared/StoreConfig.swift` 中的 `appGroupID`

> App Group 用于 App 与 Widget 共享本地数据；无权限时自动回退到应用默认容器（Widget 将显示空数据，App 功能不受影响）。

## 目录结构

```
ios/
├── project.yml               # XcodeGen 工程定义（真源）
├── App/                      # 仅主 App 编译
│   ├── SixiangApp.swift      # 入口
│   ├── RootView.swift        # 登录/主界面切换
│   ├── MainTabView.swift     # 5 Tab + URL Scheme 直达
│   ├── Core/
│   │   ├── Networking/       # APIClient（JWT/自动刷新）、DTO、Keychain
│   │   ├── Auth/             # AuthManager
│   │   ├── Sync/             # SyncEngine（离线优先、LWW、墓碑）
│   │   └── Notifications/    # 本地提醒调度
│   └── Features/
│       ├── Auth/ Today/ Tasks/ Calendar/ Notes/ Stats/ Tags/ Profile/ Tools/
├── Shared/                   # App 与 Widget 共同编译
│   ├── Models.swift          # SwiftData @Model（Task/Event/Note/Tag）
│   ├── StoreConfig.swift     # App Group 容器
│   └── Theme.swift
├── Widget/                   # 仅 Widget 扩展编译（小/中/大/锁屏 + App Intents）
└── Resources/                # Assets
```

## 关键设计

- **离线优先**：所有写入先落本地 SwiftData（`needsSync=true`），SyncEngine 防抖推送；未登录也可完整使用
- **同步冲突**：last-write-wins（`updatedAt` 裁决）+ 软删除墓碑；本地墓碑保留 30 天后清理
- **客户端生成 UUID**：离线创建与服务器 ID 一致，同步无需二次关联
- **Widget 互动**：`ToggleTaskIntent` 直接写共享 SwiftData（下次 App 同步推送）；`OpenAddTaskIntent` 通过 `sixiang://add` 直达新建
- **文件工具**：纯本地计算（SHA-256 流式哈希），通过 security-scoped bookmark 持久化文件夹授权，内容不上传
