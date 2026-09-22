/**
 * 冒烟测试：不依赖 Docker，使用嵌入式 PostgreSQL 16 完整验证后端 API。
 * 首次运行会从 Maven Central 下载 PostgreSQL 二进制（约几十 MB，需联网）。
 * 运行方式：npm run smoke（工作目录 server/）
 */
import { assert } from 'node:assert/strict';
import { mkdirSync, readFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';

async function main() {
  const dataDir = join(process.cwd(), '.pgdata-smoke');
  rmSync(dataDir, { recursive: true, force: true });
  mkdirSync(dataDir, { recursive: true });

  const { default: EmbeddedPostgres } = await import('embedded-postgres');
  const pg = new EmbeddedPostgres({
    databaseDir: dataDir,
    user: 'postgres',
    password: 'postgres',
    port: 5433,
    persistent: false,
  });

  let started = false;
  try {
    console.log('⏳ 初始化嵌入式 PostgreSQL（首次运行需下载二进制，请耐心等待）...');
    await pg.initialise();
    await pg.start();
    started = true;
    await pg.createDatabase('sixiang');
    console.log('✅ PostgreSQL 16 已启动 (localhost:5433)');

    process.env.DATABASE_URL = 'postgresql://postgres:postgres@localhost:5433/sixiang';

    const { prisma } = await import('../src/db.js');
    const initSql = readFileSync(join(process.cwd(), 'prisma', 'init.sql'), 'utf8');
    for (const stmt of initSql.split(';').map((s) => s.trim()).filter(Boolean)) {
      await prisma.$executeRawUnsafe(stmt);
    }
    console.log('✅ 表结构已创建（prisma/init.sql）');

    const { buildApp } = await import('../src/app.js');
    const app = await buildApp();

    let checks = 0;
    const expectStatus = (res: { statusCode: number; body: string }, status: number) => {
      checks++;
      assert.equal(res.statusCode, status, `期望 ${status}，实际 ${res.statusCode}，响应: ${res.body}`);
    };
    const authHeaders = (token: string) => ({ authorization: `Bearer ${token}` });

    // 1. 注册
    let res = await app.inject({
      method: 'POST',
      url: '/api/auth/register',
      payload: { email: 'demo@sixiang.app', password: 'password123', displayName: 'Demo' },
    });
    expectStatus(res, 200);
    const { accessToken, refreshToken, user } = res.json();
    assert.ok(accessToken && refreshToken && user.id);
    const userId = user.id;

    // 2. 重复注册 → 409
    res = await app.inject({
      method: 'POST',
      url: '/api/auth/register',
      payload: { email: 'demo@sixiang.app', password: 'password123' },
    });
    expectStatus(res, 409);

    // 3. 密码过短 → 400
    res = await app.inject({
      method: 'POST',
      url: '/api/auth/register',
      payload: { email: 'x@sixiang.app', password: '123' },
    });
    expectStatus(res, 400);

    // 4. 登录
    res = await app.inject({
      method: 'POST',
      url: '/api/auth/login',
      payload: { email: 'demo@sixiang.app', password: 'password123' },
    });
    expectStatus(res, 200);

    // 5. 密码错误 → 401
    res = await app.inject({
      method: 'POST',
      url: '/api/auth/login',
      payload: { email: 'demo@sixiang.app', password: 'wrongpass1' },
    });
    expectStatus(res, 401);

    // 6. 无令牌访问 → 401
    res = await app.inject({ method: 'GET', url: '/api/tasks' });
    expectStatus(res, 401);

    const H = authHeaders(accessToken);
    const t0 = new Date(Date.now() - 60_000).toISOString();

    // 7. 创建标签
    res = await app.inject({ method: 'POST', url: '/api/tags', headers: H, payload: { name: '工作', color: '#FF5500' } });
    expectStatus(res, 200);
    const tagId = res.json().id;

    // 8. 创建任务（含子任务与标签）
    res = await app.inject({
      method: 'POST',
      url: '/api/tasks',
      headers: H,
      payload: {
        title: '写设计文档',
        quadrant: 1,
        priority: 2,
        tagIds: [tagId],
        subtasks: [
          { title: '画原型', done: false, sortOrder: 0 },
          { title: '评审', done: false, sortOrder: 1 },
        ],
      },
    });
    expectStatus(res, 200);
    const taskId = res.json().id;

    // 9. 查询任务（嵌套结构）
    res = await app.inject({ method: 'GET', url: '/api/tasks', headers: H });
    expectStatus(res, 200);
    const taskList = res.json();
    assert.equal(taskList.length, 1);
    assert.equal(taskList[0].subtasks.length, 2);
    assert.equal(taskList[0].tags.length, 1);
    assert.equal(taskList[0].quadrant, 1);

    // 10. 完成任务
    res = await app.inject({
      method: 'PUT',
      url: `/api/tasks/${taskId}`,
      headers: H,
      payload: { completedAt: new Date().toISOString() },
    });
    expectStatus(res, 200);
    assert.ok(res.json().completedAt);

    // 11. 创建日程
    const startAt = new Date(Date.now() + 3_600_000).toISOString();
    const endAt = new Date(Date.now() + 7_200_000).toISOString();
    res = await app.inject({
      method: 'POST',
      url: '/api/events',
      headers: H,
      payload: { title: '项目评审', startAt, endAt, remindOffsetMinutes: 15 },
    });
    expectStatus(res, 200);
    const eventId = res.json().id;

    // 12. 日程校验：end < start → 400
    res = await app.inject({
      method: 'POST',
      url: '/api/events',
      headers: H,
      payload: { title: '非法日程', startAt: endAt, endAt: startAt },
    });
    expectStatus(res, 400);

    // 13. 创建笔记
    res = await app.inject({
      method: 'POST',
      url: '/api/notes',
      headers: H,
      payload: { title: '周报', content: '# 本周\n- 完成 M1', tagIds: [tagId] },
    });
    expectStatus(res, 200);
    const noteId = res.json().id;

    // 14. 增量同步
    res = await app.inject({ method: 'GET', url: `/api/sync?since=${t0}&deviceId=smoke-device`, headers: H });
    expectStatus(res, 200);
    const sync = res.json();
    assert.ok(sync.tasks.some((t: { id: string }) => t.id === taskId));
    assert.ok(sync.events.some((e: { id: string }) => e.id === eventId));
    assert.ok(sync.notes.some((n: { id: string }) => n.id === noteId));
    assert.ok(sync.tags.some((t: { id: string }) => t.id === tagId));
    assert.ok(sync.serverTime);

    // 15. 统计概览
    res = await app.inject({ method: 'GET', url: '/api/stats/overview?range=week', headers: H });
    expectStatus(res, 200);
    const stats = res.json();
    assert.equal(stats.daily.length, 7);
    assert.equal(stats.totals.completed, 1);
    assert.equal(stats.quadrantDistribution.q1, 1);

    // 16. 软删除 → 墓碑同步
    res = await app.inject({ method: 'DELETE', url: `/api/tasks/${taskId}`, headers: H });
    expectStatus(res, 200);
    const afterDelete = new Date(Date.now() + 1_000).toISOString();
    res = await app.inject({ method: 'GET', url: `/api/tasks?since=${afterDelete}`, headers: H });
    expectStatus(res, 200);
    assert.ok(res.json()[0].deletedAt);

    // 17. 硬删除
    res = await app.inject({ method: 'DELETE', url: `/api/tasks/${taskId}?hard=true`, headers: H });
    expectStatus(res, 200);
    res = await app.inject({ method: 'GET', url: `/api/tasks?since=${t0}`, headers: H });
    expectStatus(res, 200);
    assert.equal(res.json().length, 0);

    // 18. 刷新令牌
    res = await app.inject({ method: 'POST', url: '/api/auth/refresh', payload: { refreshToken } });
    expectStatus(res, 200);
    assert.ok(res.json().accessToken);

    // 19. 用 access 冒充 refresh → 401
    res = await app.inject({ method: 'POST', url: '/api/auth/refresh', payload: { refreshToken: accessToken } });
    expectStatus(res, 401);

    // 20. 跨用户隔离：B 用户看不到 A 的数据
    res = await app.inject({
      method: 'POST',
      url: '/api/auth/register',
      payload: { email: 'other@sixiang.app', password: 'password456' },
    });
    expectStatus(res, 200);
    const otherToken = res.json().accessToken;
    res = await app.inject({ method: 'GET', url: '/api/tasks', headers: authHeaders(otherToken) });
    expectStatus(res, 200);
    assert.equal(res.json().length, 0);

    await app.close();
    await prisma.$disconnect();
    console.log(`🎉 冒烟测试全部通过（${checks} 项断言，覆盖认证/CRUD/同步/统计/删除/隔离）`);
  } finally {
    if (started) await pg.stop().catch(() => {});
    rmSync(dataDir, { recursive: true, force: true });
  }
}

main().catch((err) => {
  console.error('❌ 冒烟测试失败:', err);
  process.exit(1);
});
