# 工作台 App — 产品与技术设计文档 v0.1（待确认）

> 面向个人的一站式效率工作台 · iOS 原生（SwiftUI）· 自建后端 + 账号体系

**实施状态：已确认并按本设计全部落地（M1–M9 完成）。** 产品名「四象」（Sixiang）。详见仓库 README.md / server/README.md / ios/README.md；iOS 构建验证走 GitHub Actions（`.github/workflows/ios-build.yml`）。

---

## 1. 产品概览

| 项目 | 决策 |
| --- | --- |
| 定位 | 个人效率工作台：任务、日程、笔记、统计、文件工具的一站式聚合 |
| 目标用户 | 个人用户，单机为主、多设备同步 |
| 平台 | iPhone 优先（iOS 17+，SwiftUI 天然适配 iPad） |
| 数据方案 | 自建后端 + 邮箱账号体系，离线优先（本地可完整使用，联网后自动同步） |
| 核心原则 | 打开即用、快速录入、数据可迁移 |

## 2. 信息架构

底部 5 个 Tab + 全局「我的」入口：

```
┌─────────────────────────────────────────────┐
│ ① 今日        ② 四象限      ③ 日历           │
│   今日任务+      2×2 任务     月/周/日视图     │
│   日程聚合       矩阵管理      日程+任务联动    │
│                                             │
│ ④ 笔记        ⑤ 看板        导航栏右侧「我的」 │
│   列表+编辑     图表统计      文件工具/账号/设置 │
└─────────────────────────────────────────────┘
```

- **今日**：聚合页——今日待办、今日日程、快捷添加，顶部打卡/完成率概览
- **四象限**：任务主视图（重要×紧急 2×2），支持拖拽换象限；可切换列表视图
- **日历**：月/周/日视图 + 今日时间轴；带截止时间的任务同步显示
- **笔记**：笔记列表 + 搜索 + 标签 + 编辑
- **看板**：完成率趋势、四象限分布、热力图等统计图表
- **我的**（导航栏入口）：文件工具、账号管理、设置、数据导出

## 3. 功能设计

### 3.1 待办任务（四象限）
- 任务字段：标题、备注、象限（重要/紧急 2×2）、优先级、截止时间、提醒、标签、子任务、重复规则、图片附件
- 视图：四象限矩阵（拖拽移动）、列表（今天/计划/全部分组，支持筛选）
- 操作：勾选完成（带动效）、左滑推迟/删除、长按排序、快捷添加
- 扩展：Siri 快捷指令（App Intents）、Widget 勾选完成

### 3.2 日历 / 日程
- 视图：月 / 周 / 日 + 今日时间轴（当前时刻指示线）
- 日程字段：标题、起止时间、地点、备注、提前 N 分钟提醒、重复规则
- 联动：带截止时间的任务显示在日历（可开关）
- 系统集成（可选）：EventKit 与系统日历双向同步
- 提醒：本地通知（离线可用）+ 后端 APNs 推送

### 3.3 笔记 / 备忘录
- Markdown 所见即所得编辑器（标题/列表/待办/引用/代码块）
- 列表支持搜索、标签、置顶、归档
- 图片附件；笔记内待办清单块可一键转为任务
- 自动保存（本地实时 + 云端异步）

### 3.4 数据看板
- 概览卡：今日完成率、连续打卡天数、本周趋势
- 图表（Swift Charts）：完成率折线、四象限分布环形图、每日完成热力图、标签分布
- 周期切换：周 / 月 / 年
- 数据来源：本地聚合为主，后端统计接口兜底

### 3.5 文件工具（文件夹对比）
- 文件夹选择：系统文件选择器 + security-scoped bookmark 持久化授权
- **文件夹对比**：选择两个文件夹，先按 名称+大小+修改时间 快比，可选 SHA-256 内容哈希深比；结果分「仅左侧 / 仅右侧 / 两侧不同 / 相同」四类，可筛选、导出报告（CSV/JSON）
- **重复文件查找**：按大小分组 + 哈希确认
- **大文件扫描**：按大小排序，找出占空间大户
- 全部本地计算，**文件内容不上传**（隐私）；大目录对比放后台任务 + 进度条

### 3.6 桌面小组件（WidgetKit）
| 尺寸 | 内容 |
| --- | --- |
| 小 | 今日剩余任务数 / 连续打卡环形进度 |
| 中 | 今日待办前 4 条 + 快速添加按钮 |
| 大 | 四象限概览 或 本周完成趋势 |
| 锁屏 | 今日完成率环形图 |

- 互动：App Intents 支持勾选完成、快速添加
- 数据共享：App Groups 读取本地缓存，离线可用

### 3.7 账号与设置
- 注册/登录（邮箱 + 密码），JWT（access 短效 + refresh 长效），Keychain 安全存储
- 设置：主题（浅/深/跟随系统）、默认提醒时间、通知开关、同步状态、数据导出

## 4. 技术架构

### 4.1 iOS 端
- SwiftUI（iOS 17+），MVVM + Observation 框架
- **SwiftData** 本地缓存（离线优先，所有读写先落本地）
- 图表：Swift Charts；小组件：WidgetKit + App Intents
- 网络：URLSession + async/await + Codable
- App Groups 共享（Widget 数据）；UserNotifications 本地通知
- 文件访问：UIDocumentPicker + security-scoped bookmarks

### 4.2 后端（自建）
- Node.js + TypeScript + Fastify（或 NestJS）
- PostgreSQL + Prisma ORM
- REST API + JWT 认证（bcrypt 密码哈希）
- APNs 推送服务；Docker Compose 一键部署
- 说明：后端在本机（Windows）即可开发与联调；iOS 编译需 macOS/Xcode（见 §8）

### 4.3 同步策略（离线优先）
- 写操作先落本地 SwiftData，后台队列异步推送到服务器
- 首次登录全量拉取；之后按 `updatedAt > since` 增量同步
- 冲突解决：last-write-wins + 软删除墓碑（deletedAt）
- UI 显示同步状态（未同步/同步中/已同步）

## 5. 核心数据模型

| 表 | 关键字段 |
| --- | --- |
| users | id, email, password_hash, created_at |
| tasks | id, user_id, title, note, quadrant(1-4), priority, due_at, completed_at, deleted_at, repeat_rule, sort_order, timestamps |
| subtasks | id, task_id, title, done |
| events | id, user_id, title, start_at, end_at, location, note, remind_offset, repeat_rule, deleted_at, timestamps |
| notes | id, user_id, title, content(markdown), pinned, archived, deleted_at, timestamps |
| tags | id, user_id, name, color |
| attachments | id, user_id, file_path, size, mime, timestamps |
| device_sync | user_id, device_id, last_synced_at |

## 6. API 概览（REST）

```
POST /api/auth/register | login | refresh | logout
GET  /api/me
GET  /api/sync?since=...              # 增量同步入口（任务/日程/笔记/标签/附件）
GET|POST|PUT|DELETE /api/tasks /api/events /api/notes
GET  /api/stats/overview?range=week|month|year
```
> 文件对比模块纯本地计算，无服务端 API。

## 7. 实施里程碑

| 阶段 | 内容 | 交付物 |
| --- | --- | --- |
| M1 | 后端：认证 + 任务/日程/笔记 CRUD + 增量同步 API + 统计接口 | 可联调的服务（本机可跑） |
| M2 | iOS 工程骨架：Tab 结构、登录注册、SwiftData 缓存、同步引擎 | 可运行的 App 外壳 |
| M3 | 四象限任务模块 | 完整任务管理 |
| M4 | 日历/日程 + 系统日历联动 | 完整日历 |
| M5 | 笔记模块 | 完整笔记 |
| M6 | 数据看板（图表） | 完整统计 |
| M7 | Widget 小组件 + App Intents | 桌面/锁屏小组件 |
| M8 | 文件工具（文件夹对比/重复文件/大文件） | 完整文件工具 |
| M9 | 打磨：动画、空态、暗色模式、性能与测试 | 发布候选版 |

## 8. 风险与依赖

1. **iOS 编译环境**：当前开发机为 Windows，无法本机编译 iOS。需要：① 你有 Mac + Xcode 本地构建；或 ② 用 CI（GitHub Actions macOS runner）自动构建。源码与工程文件可由我完整产出。
2. **APNs 推送**：需要 Apple Developer 账号（个人 $99/年）与 APNs 证书；无账号时先用本地通知，接口预留。
3. **自建后端上线**：需服务器 + 域名 + HTTPS（开发阶段本机 localhost 即可）。
4. **大目录哈希对比耗时**：置于后台任务、分批计算、可取消、显示进度。

## 9. 实施完成清单（2026-09-22 更新）

1. ~~App 名称~~ → **「四象」**
2. ~~后端技术栈~~ → Node.js + TypeScript + Fastify + Prisma + PostgreSQL ✓
3. ~~iOS 构建方式~~ → 无 Mac，GitHub Actions CI 构建 ✓
4. ~~最低支持 iOS 版本~~ → iOS 17（SwiftData）✓

M1 后端（冒烟测试 24 项断言全通过）→ M2 工程骨架 → M3 四象限 → M4 日历 → M5 笔记 → M6 看板 → M7 Widget → M8 文件工具 → M9 CI + 文档，均已交付。
