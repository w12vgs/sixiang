# 四象 Sixiang · 个人效率工作台（iOS）

一站式个人效率工作台：**四象限任务 · 日历日程 · 笔记 · 数据看板 · 文件夹对比工具**，iOS 原生（SwiftUI）+ 自建后端，离线优先、多设备同步。

- 📐 设计文档：[`DESIGN.md`](DESIGN.md)
- 🖥 后端：`server/` — Node.js + TypeScript + Fastify + Prisma + PostgreSQL（详见 [`server/README.md`](server/README.md)）
- 📱 客户端：`ios/` — SwiftUI（iOS 17+）+ SwiftData + WidgetKit（详见 [`ios/README.md`](ios/README.md)）
- 🔧 CI：`.github/workflows/` — 后端全量 API 测试 + iOS 自动构建

## 目录结构

```
.
├── DESIGN.md                  # 产品与技术设计文档
├── server/                    # 后端 API 服务（含冒烟测试）
├── ios/                       # iOS 客户端（XcodeGen 工程 + Widget）
│   ├── project.yml            # 工程定义（真源，xcodeproj 不入库）
│   ├── App/                   # 主 App 源码
│   ├── Shared/                # App 与 Widget 共享（模型/容器/主题）
│   └── Widget/                # 小组件 + App Intents
└── .github/workflows/         # CI（server-ci / ios-build）
```

## 快速开始

### 后端

```bash
cd server
npm install
npm run smoke      # 无 Docker 也可完整验证 API（自动下载嵌入式 PostgreSQL）
# 或
docker compose up -d --build   # 一键部署（API + PostgreSQL）
```

### iOS 客户端

在 macOS 上：

```bash
cd ios
brew install xcodegen
xcodegen generate
open Sixiang.xcodeproj
```

> 无 Mac？推送 GitHub 由 Actions 自动构建验证（见下）。

## CI / 自动构建（无 Mac 也能验证 iOS 构建）

```bash
git remote add origin https://github.com/<你的账号>/sixiang.git
git branch -M main
git push -u origin main
```

推送后自动触发：
- **Server CI**：`npm ci` → Prisma 生成 → 类型检查 → **24 项 API 冒烟断言**（嵌入式 PostgreSQL）
- **iOS Build**：macOS runner 上 xcodegen 生成工程 → xcodebuild 构建 App + Widget（模拟器目标、免签名）

## 功能一览

| 模块 | 说明 |
| --- | --- |
| 今日 | 逾期/今日待办/今日日程聚合 + 快速添加 |
| 四象限 | 2×2 矩阵（拖拽换象限）、列表筛选、子任务、标签、优先级、提醒 |
| 日历 | 月视图 + 日议程，日程与任务联动，全天/提醒 |
| 笔记 | Markdown 编辑/预览、标签、置顶、搜索 |
| 看板 | 连续打卡、完成率、趋势图、四象限分布（Swift Charts，本地聚合） |
| Widget | 小/中/大/锁屏，勾选完成（App Intent 离线可用）、快速添加直达 |
| 文件工具 | 文件夹对比（快速/ SHA-256 深度）、重复文件查找、大文件扫描，纯本地计算 |
| 同步 | 离线优先 + 增量同步 + LWW 冲突裁决 + 软删除墓碑；JWT 账号体系 |

## 里程碑进度

- [x] M1 后端：认证 / 任务 / 日程 / 笔记 / 标签 / 增量同步 / 统计 API（冒烟测试 24 项断言全通过）
- [x] M2 iOS 工程骨架（登录、Tab 结构、本地缓存、同步引擎）
- [x] M3 四象限任务
- [x] M4 日历/日程
- [x] M5 笔记
- [x] M6 数据看板
- [x] M7 Widget 小组件
- [x] M8 文件工具
- [x] M9 CI 构建 + 文档
