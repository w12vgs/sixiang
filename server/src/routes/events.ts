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

const eventSchema = z.object({
  id: z.string().uuid().optional(), // 客户端离线生成
  title: z.string().min(1).max(500),
  note: z.string().max(20000).nullable().optional(),
  location: z.string().max(500).nullable().optional(),
  startAt: z.string().datetime(),
  endAt: z.string().datetime(),
  allDay: z.boolean().default(false),
  remindOffsetMinutes: z.number().int().min(0).max(10080).nullable().optional(),
  repeatRule: z.string().max(500).nullable().optional(),
  calendarId: z.string().max(200).nullable().optional(),
});

const endAtValid = (v: { startAt?: string; endAt?: string }) =>
  v.startAt && v.endAt ? new Date(v.endAt) >= new Date(v.startAt) : true;

const eventCreateSchema = eventSchema.refine(endAtValid, {
  message: 'endAt must be >= startAt',
  path: ['endAt'],
});

const eventUpdateSchema = eventSchema.partial().refine(endAtValid, {
  message: 'endAt must be >= startAt',
  path: ['endAt'],
});

type EventUpdateBody = z.infer<typeof eventUpdateSchema>;

function buildEventData(body: EventUpdateBody): Prisma.EventUncheckedUpdateInput {
  const data: Prisma.EventUncheckedUpdateInput = {};
  for (const key of ['title', 'note', 'location', 'allDay', 'remindOffsetMinutes', 'repeatRule', 'calendarId'] as const) {
    if (body[key] !== undefined) (data as Record<string, unknown>)[key] = body[key];
  }
  for (const key of ['startAt', 'endAt'] as const) {
    if (body[key] !== undefined) {
      (data as Record<string, unknown>)[key] = body[key] ? new Date(body[key] as string) : null;
    }
  }
  return data;
}

export async function eventRoutes(app: FastifyInstance) {
  app.get('/api/events', { preHandler: requireAuth }, async (req, reply) => {
    try {
      const q = sinceQuery.parse(req.query);
      const where: Prisma.EventWhereInput = { userId: req.user.sub };
      if (q.since) {
        const since = new Date(q.since);
        where.OR = [{ updatedAt: { gt: since } }, { deletedAt: { gt: since } }];
      } else {
        where.deletedAt = null;
      }
      return await prisma.event.findMany({ where, orderBy: { updatedAt: 'asc' } });
    } catch (err) {
      return handleError(err, reply);
    }
  });

  app.get('/api/events/:id', { preHandler: requireAuth }, async (req, reply) => {
    try {
      const { id } = z.object({ id: z.string().uuid() }).parse(req.params);
      const event = await prisma.event.findFirst({ where: { id, userId: req.user.sub } });
      if (!event) throw new HttpError(404, 'not_found');
      return event;
    } catch (err) {
      return handleError(err, reply);
    }
  });

  app.post('/api/events', { preHandler: requireAuth }, async (req, reply) => {
    try {
      const body = eventCreateSchema.parse(req.body);
      return await prisma.event.create({
        data: { ...buildEventData(body), id: body.id, userId: req.user.sub } as Prisma.EventUncheckedCreateInput,
      });
    } catch (err) {
      return handleError(err, reply);
    }
  });

  app.put('/api/events/:id', { preHandler: requireAuth }, async (req, reply) => {
    try {
      const { id } = z.object({ id: z.string().uuid() }).parse(req.params);
      const body = eventUpdateSchema.parse(req.body);
      const r = await prisma.event.updateMany({
        where: { id, userId: req.user.sub },
        data: buildEventData(body),
      });
      if (r.count === 0) throw new HttpError(404, 'not_found');
      return await prisma.event.findFirst({ where: { id, userId: req.user.sub } });
    } catch (err) {
      return handleError(err, reply);
    }
  });

  app.delete('/api/events/:id', { preHandler: requireAuth }, async (req, reply) => {
    try {
      const { id } = z.object({ id: z.string().uuid() }).parse(req.params);
      const q = sinceQuery.parse(req.query);
      if (q.hard === 'true') {
        const r = await prisma.event.deleteMany({ where: { id, userId: req.user.sub } });
        if (r.count === 0) throw new HttpError(404, 'not_found');
        return { ok: true, hard: true };
      }
      const r = await prisma.event.updateMany({
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
