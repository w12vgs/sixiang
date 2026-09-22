import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { Prisma } from '@prisma/client';
import { prisma } from '../db.js';
import { handleError } from '../errors.js';
import { requireAuth } from '../auth.js';

const syncQuery = z.object({
  since: z.string().datetime().optional(),
  deviceId: z.string().min(1).max(100).optional(),
});

const taskInclude = {
  subtasks: { orderBy: { sortOrder: 'asc' as const } },
  tagLinks: { include: { tag: true } },
};
const noteInclude = { tagLinks: { include: { tag: true } } };

function serializeTask(task: Prisma.TaskGetPayload<{ include: typeof taskInclude }>) {
  const { tagLinks, ...rest } = task;
  return { ...rest, tags: tagLinks.map((l) => l.tag).filter((t) => !t.deletedAt) };
}

function serializeNote(note: Prisma.NoteGetPayload<{ include: typeof noteInclude }>) {
  const { tagLinks, ...rest } = note;
  return { ...rest, tags: tagLinks.map((l) => l.tag).filter((t) => !t.deletedAt) };
}

/** 增量同步入口：一次拉取全部实体类型的变更（含删除墓碑） */
export async function syncRoutes(app: FastifyInstance) {
  app.get('/api/sync', { preHandler: requireAuth }, async (req, reply) => {
    try {
      const q = syncQuery.parse(req.query);
      const userId = req.user.sub;
      const since = q.since ? new Date(q.since) : new Date(0);
      const changed = { gt: since };

      const [tasks, events, notes, tags, attachments] = await Promise.all([
        prisma.task.findMany({
          where: { userId, OR: [{ updatedAt: changed }, { deletedAt: changed }] },
          include: taskInclude,
          orderBy: { updatedAt: 'asc' },
        }),
        prisma.event.findMany({
          where: { userId, OR: [{ updatedAt: changed }, { deletedAt: changed }] },
          orderBy: { updatedAt: 'asc' },
        }),
        prisma.note.findMany({
          where: { userId, OR: [{ updatedAt: changed }, { deletedAt: changed }] },
          include: noteInclude,
          orderBy: { updatedAt: 'asc' },
        }),
        prisma.tag.findMany({
          where: { userId, OR: [{ updatedAt: changed }, { deletedAt: changed }] },
          orderBy: { updatedAt: 'asc' },
        }),
        prisma.attachment.findMany({ where: { userId, createdAt: changed } }),
      ]);

      if (q.deviceId) {
        await prisma.deviceSync.upsert({
          where: { userId_deviceId: { userId, deviceId: q.deviceId } },
          create: { userId, deviceId: q.deviceId, lastSyncedAt: new Date() },
          update: { lastSyncedAt: new Date() },
        });
      }

      return {
        serverTime: new Date().toISOString(),
        since: q.since ?? null,
        tasks: tasks.map(serializeTask),
        events,
        notes: notes.map(serializeNote),
        tags,
        attachments,
      };
    } catch (err) {
      return handleError(err, reply);
    }
  });
}
