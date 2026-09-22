# 四象 Sixiang · 个人效率工作台（iOS）

一站式个人效率工作台：**四象限任务 · 日历日程 · 笔记 · 数据看板 · 文件夹对比工具**，iOS 原生（SwiftUI）+ 自建后端，离线优先、多设备同步。

- 📐 设计文档：[`DESIGN.md`](DESIGN.md)
- 🖥 后端：`server/` — Node.js + TypeScript + Fastify + Prisma + PostgreSQL（详见 [`server/README.md`](server/README.md)）
- 📱 客户端：`ios/` — SwiftUI（iOS 17+）+ SwiftData + WidgetKit，XcodeGen 生成工程
- 🔧 CI：`.github/workflows/` — 后端测试 + iOS 自动构建（GitHub Actions macOS）

## 目录结构

```
.
├── DESIGN.md             # 产品与技术设计文档
├── server/               # 后端 API 服务
├── ios/                  # iOS 客户端（XcodeGen 工程）
│   ├── project.yml       # XcodeGen 工程定义
│   └── Sixiang/          # App 源码 + Widget 扩展
└── .github/workflows/    # CI 配置
```

## 快速开始

### 后端

```bash
cd server
npm install
npm run smoke      # 无 Docker 也可完整验证 API（嵌入式 PostgreSQL）
# 或
docker compose up -d --build
```

### iOS 客户端

在 macOS 上：

```bash
cd ios
brew install xcodegen
xcodegen generate
open Sixiang.xcodeproj   # Xcode 运行
```

> iOS 构建需要 macOS + Xcode；无 Mac 环境可推送 GitHub 后由 Actions 自动构建（见 `.github/workflows/ios-build.yml`）。

## 里程碑进度

- [x] M1 后端：认证 / 任务 / 日程 / 笔记 / 标签 / 增量同步 / 统计 API
- [ ] M2 iOS 工程骨架（登录、Tab 结构、本地缓存、同步引擎）
- [ ] M3 四象限任务
- [ ] M4 日历/日程
- [ ] M5 笔记
- [ ] M6 数据看板
- [ ] M7 Widget 小组件
- [ ] M8 文件工具
- [ ] M9 CI 构建 + 打磨
