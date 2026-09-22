import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { Prisma } from '@prisma/client';
import { prisma } from '../db.js';
import { HttpError, handleError } from '../errors.js';
import { requireAuth } from '../auth.js';

const sinceQuery = z.object({ since: z.string().datetime().optional() });

const tagCreateSchema = z.object({
  id: z.string().uuid().optional(), // 客户端离线生成
  name: z.string().min(1).max(50),
  color: z
    .string()
    .regex(/^#[0-9A-Fa-f]{6}$/)
    .default('#5E6AD2'),
});

const tagUpdateSchema = tagCreateSchema.partial();

export async function tagRoutes(app: FastifyInstance) {
  // 活动标签（不含已删除）
  app.get('/api/tags', { preHandler: requireAuth }, async (req, reply) => {
    try {
      sinceQuery.parse(req.query);
      return await prisma.tag.findMany({
        where: { userId: req.user.sub, deletedAt: null },
        orderBy: { name: 'asc' },
      });
    } catch (err) {
      return handleError(err, reply);
    }
  });

  app.post('/api/tags', { preHandler: requireAuth }, async (req, reply) => {
    try {
      const body = tagCreateSchema.parse(req.body);
      return await prisma.tag.create({ data: { ...body, id: body.id, userId: req.user.sub } });
    } catch (err) {
      return handleError(err, reply);
    }
  });

  app.put('/api/tags/:id', { preHandler: requireAuth }, async (req, reply) => {
    try {
      const { id } = z.object({ id: z.string().uuid() }).parse(req.params);
      const body = tagUpdateSchema.parse(req.body);
      const r = await prisma.tag.updateMany({
        where: { id, userId: req.user.sub, deletedAt: null },
        data: body,
      });
      if (r.count === 0) throw new HttpError(404, 'not_found');
      return await prisma.tag.findUnique({ where: { id } });
    } catch (err) {
      return handleError(err, reply);
    }
  });

  // 软删除（墓碑同步到其他设备）
  app.delete('/api/tags/:id', { preHandler: requireAuth }, async (req, reply) => {
    try {
      const { id } = z.object({ id: z.string().uuid() }).parse(req.params);
      const r = await prisma.tag.updateMany({
        where: { id, userId: req.user.sub, deletedAt: null },
        data: { deletedAt: new Date() },
      });
      if (r.count === 0) throw new HttpError(404, 'not_found');
      return { ok: true };
    } catch (err) {
      return handleError(err, reply);
    }
  });
}
