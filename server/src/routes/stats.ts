import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { prisma } from '../db.js';
import { handleError } from '../errors.js';
import { requireAuth } from '../auth.js';

const statsQuery = z.object({
  range: z.enum(['week', 'month', 'year']).default('week'),
  end: z.string().datetime().optional(),
});

/**
 * 统计概览：
 * - daily: 每日创建/完成数
 * - quadrantDistribution: 四象限分布（未删除任务）
 * - totals: 未完成/已完成/完成率
 * - streak: 截至 end 的连续打卡天数
 * 注：基于范围内「创建或完成」的任务聚合（v1 简化口径）。
 */
export async function statsRoutes(app: FastifyInstance) {
  app.get('/api/stats/overview', { preHandler: requireAuth }, async (req, reply) => {
    try {
      const q = statsQuery.parse(req.query);
      const end = q.end ? new Date(q.end) : new Date();
      const days = q.range === 'week' ? 7 : q.range === 'month' ? 30 : 365;
      const start = new Date(end);
      start.setUTCDate(start.getUTCDate() - (days - 1));
      start.setUTCHours(0, 0, 0, 0);

      const tasks = await prisma.task.findMany({
        where: {
          userId: req.user.sub,
          OR: [{ createdAt: { gte: start } }, { completedAt: { gte: start } }],
        },
        select: { quadrant: true, createdAt: true, completedAt: true, deletedAt: true },
      });

      const dayKey = (d: Date) => d.toISOString().slice(0, 10);
      const daily = new Map<string, { date: string; created: number; completed: number }>();
      for (let i = 0; i < days; i++) {
        const d = new Date(start);
        d.setUTCDate(start.getUTCDate() + i);
        daily.set(dayKey(d), { date: dayKey(d), created: 0, completed: 0 });
      }

      const quadrant = { q1: 0, q2: 0, q3: 0, q4: 0 };
      let open = 0;
      let completed = 0;

      for (const t of tasks) {
        const ck = dayKey(t.createdAt);
        if (daily.has(ck)) daily.get(ck)!.created++;
        if (t.completedAt) {
          const fk = dayKey(t.completedAt);
          if (daily.has(fk)) daily.get(fk)!.completed++;
        }
        if (t.deletedAt) continue;
        quadrant[`q${t.quadrant}` as keyof typeof quadrant]++;
        if (t.completedAt) completed++;
        else open++;
      }

      // 连续打卡：从 end 往前数每天至少完成 1 个
      let streak = 0;
      const cursor = new Date(end);
      cursor.setUTCHours(0, 0, 0, 0);
      for (;;) {
        const entry = daily.get(dayKey(cursor));
        if (entry && entry.completed > 0) {
          streak++;
          cursor.setUTCDate(cursor.getUTCDate() - 1);
        } else {
          break;
        }
      }

      return {
        range: q.range,
        start: start.toISOString(),
        end: end.toISOString(),
        daily: [...daily.values()],
        quadrantDistribution: quadrant,
        totals: {
          open,
          completed,
          completionRate: open + completed > 0 ? completed / (open + completed) : 0,
        },
        streak,
      };
    } catch (err) {
      return handleError(err, reply);
    }
  });
}
