import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { Prisma } from '@prisma/client';
import { prisma } from '../db.js';
import { HttpError, handleError } from '../errors.js';
import { requireAuth } from '../auth.js';

const sinceQuery = z.object({
  since: z.string().datetime().optional(),
  hard: z.enum(['true', 'false']).optional(),
});

const subtaskSchema = z.object({
  id: z.string().uuid(),
  title: z.string().min(1).max(1000),
  done: z.boolean().default(false),
  sortOrder: z.number().int().default(0),
});

const taskCreateSchema = z.object({
  id: z.string().uuid().optional(), // 客户端离线生成，保持离线-在线 ID 一致
  title: z.string().min(1).max(500),
  note: z.string().max(20000).nullable().optional(),
  quadrant: z.number().int().min(1).max(4).default(1),
  priority: z.number().int().min(1).max(3).default(2),
  dueAt: z.string().datetime().nullable().optional(),
  reminderAt: z.string().datetime().nullable().optional(),
  repeatRule: z.string().max(500).nullable().optional(),
  sortOrder: z.number().int().default(0),
  completedAt: z.string().datetime().nullable().optional(),
  tagIds: z.array(z.string().uuid()).optional(),
  subtasks: z.array(subtaskSchema).optional(),
});

const taskUpdateSchema = taskCreateSchema.partial();

type TaskUpdateBody = z.infer<typeof taskUpdateSchema>;

const taskInclude = {
  subtasks: { orderBy: { sortOrder: 'asc' as const } },
  tagLinks: { include: { tag: true } },
};

type TaskWithLinks = Prisma.TaskGetPayload<{ include: typeof taskInclude }>;

function serializeTask(task: TaskWithLinks) {
  const { tagLinks, ...rest } = task;
  return { ...rest, tags: tagLinks.map((l) => l.tag).filter((t) => !t.deletedAt) };
}

/** 组装写入数据：字符串日期 → Date，undefined 跳过，null 置空 */
function buildTaskData(body: TaskUpdateBody): Prisma.TaskUncheckedUpdateInput {
  const data: Prisma.TaskUncheckedUpdateInput = {};
  for (const key of ['title', 'note', 'quadrant', 'priority', 'sortOrder', 'repeatRule'] as const) {
    if (body[key] !== undefined) (data as Record<string, unknown>)[key] = body[key];
  }
  for (const key of ['dueAt', 'reminderAt', 'completedAt'] as const) {
    if (body[key] !== undefined) {
      (data as Record<string, unknown>)[key] = body[key] ? new Date(body[key] as string) : null;
    }
  }
  return data;
}

async function fetchTask(userId: string, taskId: string) {
  const task = await prisma.task.findFirst({
    where: { id: taskId, userId },
    include: taskInclude,
  });
  if (!task) throw new HttpError(404, 'not_found');
  return serializeTask(task);
}

export async function taskRoutes(app: FastifyInstance) {
  // 任务列表；带 since 时返回增量（含删除墓碑）
  app.get('/api/tasks', { preHandler: requireAuth }, async (req, reply) => {
    try {
      const q = sinceQuery.parse(req.query);
      const where: Prisma.TaskWhereInput = { userId: req.user.sub };
      if (q.since) {
        const since = new Date(q.since);
        where.OR = [{ updatedAt: { gt: since } }, { deletedAt: { gt: since } }];
      } else {
        where.deletedAt = null;
      }
      const tasks = await prisma.task.findMany({
        where,
        include: taskInclude,
        orderBy: { updatedAt: 'asc' },
      });
      return tasks.map(serializeTask);
    } catch (err) {
      return handleError(err, reply);
    }
  });

  app.get('/api/tasks/:id', { preHandler: requireAuth }, async (req, reply) => {
    try {
      const { id } = z.object({ id: z.string().uuid() }).parse(req.params);
      return await fetchTask(req.user.sub, id);
    } catch (err) {
      return handleError(err, reply);
    }
  });

  app.post('/api/tasks', { preHandler: requireAuth }, async (req, reply) => {
    try {
      const body = taskCreateSchema.parse(req.body);
      await prisma.$transaction(async (tx) => {
        const task = await tx.task.create({
          data: { ...buildTaskData(body), id: body.id, userId: req.user.sub } as Prisma.TaskUncheckedCreateInput,
        });
        if (body.tagIds?.length) {
          await tx.taskTag.createMany({ data: body.tagIds.map((tagId) => ({ taskId: task.id, tagId })) });
        }
        if (body.subtasks?.length) {
          await tx.subtask.createMany({
            data: body.subtasks.map((s) => ({ id: s.id, title: s.title, done: s.done, sortOrder: s.sortOrder, taskId: task.id })),
          });
        }
        return task;
      });
      const created = await prisma.task.findFirst({
        where: { userId: req.user.sub, id: body.id },
        include: taskInclude,
      });
      if (!created) throw new HttpError(500, 'internal_error');
      return serializeTask(created);
    } catch (err) {
      return handleError(err, reply);
    }
  });

  app.put('/api/tasks/:id', { preHandler: requireAuth }, async (req, reply) => {
    try {
      const { id } = z.object({ id: z.string().uuid() }).parse(req.params);
      const body = taskUpdateSchema.parse(req.body);
      const existing = await prisma.task.findFirst({ where: { id, userId: req.user.sub } });
      if (!existing) throw new HttpError(404, 'not_found');

      await prisma.$transaction(async (tx) => {
        await tx.task.update({ where: { id }, data: buildTaskData(body) });
        if (body.tagIds !== undefined) {
          await tx.taskTag.deleteMany({ where: { taskId: id } });
          if (body.tagIds.length) {
            await tx.taskTag.createMany({ data: body.tagIds.map((tagId) => ({ taskId: id, tagId })) });
          }
          await tx.task.update({ where: { id }, data: { updatedAt: new Date() } });
        }
        if (body.subtasks !== undefined) {
          await tx.subtask.deleteMany({ where: { taskId: id } });
          if (body.subtasks.length) {
            await tx.subtask.createMany({
              data: body.subtasks.map((s) => ({ id: s.id, title: s.title, done: s.done, sortOrder: s.sortOrder, taskId: id })),
            });
          }
          await tx.task.update({ where: { id }, data: { updatedAt: new Date() } });
        }
      });
      return await fetchTask(req.user.sub, id);
    } catch (err) {
      return handleError(err, reply);
    }
  });

  // 软删除（默认，同步为墓碑）；?hard=true 为物理删除
  app.delete('/api/tasks/:id', { preHandler: requireAuth }, async (req, reply) => {
    try {
      const { id } = z.object({ id: z.string().uuid() }).parse(req.params);
      const q = sinceQuery.parse(req.query);
      if (q.hard === 'true') {
        const r = await prisma.task.deleteMany({ where: { id, userId: req.user.sub } });
        if (r.count === 0) throw new HttpError(404, 'not_found');
        return { ok: true, hard: true };
      }
      const r = await prisma.task.updateMany({
        where: { id, userId: req.user.sub, deletedAt: null },
        data: { deletedAt: new Date() },
      });
      if (r.count === 0) throw new HttpError(404, 'not_found');
      return { ok: true, hard: false };
    } catch (err) {
      return handleError(err, reply);
    }
  });
}
