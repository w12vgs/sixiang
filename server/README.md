# 四象 Sixiang · 后端服务

Node.js + TypeScript + Fastify + Prisma + PostgreSQL。提供账号认证、任务/日程/笔记/标签 CRUD、增量同步与统计 API。

## 快速开始

### 方式一：Docker Compose（推荐，一条命令）

```bash
cd server
cp .env.example .env   # 修改 JWT_SECRET
docker compose up -d --build
# API: http://localhost:3000/api/health
```

### 方式二：本机开发（需本机 PostgreSQL）

```bash
cd server
npm install
cp .env.example .env   # 修改 DATABASE_URL 指向你的 PostgreSQL
npx prisma db push     # 按 schema.prisma 建表
npm run dev            # 热重载开发模式
```

### 无 Docker / 无 PostgreSQL：冒烟测试

```bash
cd server
npm install
npm run smoke
```

冒烟测试会自动下载并启动嵌入式 PostgreSQL 16+，执行 24 组断言（认证、CRUD、客户端 ID、同步、统计、软删除墓碑、跨用户隔离），全程无需外部依赖。

> 受限沙箱环境（进程无法拉起子进程时）：`npm run build` 后执行
> `& .\scripts\run-smoke-local.ps1`（Windows，用 @embedded-postgres 自带二进制 + 外部启动方式跑同一套断言）。

## 脚本

| 命令 | 说明 |
| --- | --- |
| `npm run dev` | tsx watch 热重载开发 |
| `npm run build` | 编译到 dist/ |
| `npm start` | 运行编译产物 |
| `npm run db:push` | 按 schema.prisma 同步表结构（幂等） |
| `npm run smoke` | 嵌入式 PG 冒烟测试 |

## API 概览

认证采用 JWT：access token 短效（默认 15m），refresh token 长效（默认 30d）。
除注册/登录/刷新/健康检查外，均需请求头 `Authorization: Bearer <accessToken>`。

### 认证

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| POST | `/api/auth/register` | `{ email, password(≥8), displayName? }` → `{ user, accessToken, refreshToken }` |
| POST | `/api/auth/login` | `{ email, password }` → 同上 |
| POST | `/api/auth/refresh` | `{ refreshToken }` → 新令牌对 |
| POST | `/api/auth/logout` | 客户端丢弃令牌即可（v1 无状态） |
| GET | `/api/me` | 当前用户信息 |

### 资源 CRUD

通用约定：
- 列表 `GET /api/tasks`：不带 `since` 返回全部未删除；带 `since=<ISO>` 返回该时刻之后的变更（**含删除墓碑** `deletedAt`）
- `DELETE /api/tasks/:id`：默认软删除；`?hard=true` 物理删除
- 字段名与 Prisma 模型一致（camelCase），时间统一 ISO 8601 字符串

| 资源 | 路径 | 特殊字段 |
| --- | --- | --- |
| 任务 | `/api/tasks` | `quadrant`(1-4), `priority`(1-3), `dueAt`, `reminderAt`, `repeatRule`(JSON 串), `tagIds[]`, `subtasks[]`（子任务整体替换） |
| 日程 | `/api/events` | `startAt`, `endAt`, `allDay`, `remindOffsetMinutes`, `repeatRule`, `calendarId`（EventKit 联动） |
| 笔记 | `/api/notes` | `content`(Markdown), `pinned`, `archived`, `tagIds[]` |
| 标签 | `/api/tags` | `name`(同用户唯一), `color`(#RRGGBB)，删除为软删除（墓碑同步） |

### 同步与统计

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/api/sync?since=<ISO>&deviceId=<id>` | 一次返回 tasks/events/notes/tags/attachments 五类增量 + `serverTime` |
| GET | `/api/stats/overview?range=week\|month\|year&end=<ISO>` | `daily[]`, `quadrantDistribution`, `totals{open,completed,completionRate}`, `streak` |

### 错误约定

```json
{ "error": "validation_error" | "unauthorized" | "invalid_credentials" | "already_exists" | "not_found" | "internal_error" }
```

状态码：400 校验 / 401 认证 / 404 不存在 / 409 冲突 / 500 服务器。

## 环境变量

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `PORT` | 3000 | 监听端口 |
| `HOST` | 0.0.0.0 | 监听地址 |
| `DATABASE_URL` | - | PostgreSQL 连接串 |
| `JWT_SECRET` | dev-secret-change-me | **生产必改** |
| `ACCESS_TOKEN_TTL` | 15m | access token 有效期 |
| `REFRESH_TOKEN_TTL` | 30d | refresh token 有效期 |

## 架构要点

- **软删除墓碑**：删除只写 `deletedAt`，增量同步凭它通知各端；`?hard=true` 才物理删除
- **嵌套结构**：任务/笔记响应含 `tags[]`、任务含 `subtasks[]`；`tagIds` 提交时整体替换关联
- **同步冲突策略**：last-write-wins，客户端以 `updatedAt` 新旧裁决
- **跨用户隔离**：所有查询强制 `userId` 过滤
- **统计口径**：基于范围内「创建或完成」的任务聚合（v1 简化，详见 stats.ts 注释）
