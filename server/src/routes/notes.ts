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

const noteCreateSchema = z.object({
  id: z.string().uuid().optional(), // 客户端离线生成
  title: z.string().min(1).max(500),
  content: z.string().max(200000).default(''),
  pinned: z.boolean().default(false),
  archived: z.boolean().default(false),
  tagIds: z.array(z.string().uuid()).optional(),
});

const noteUpdateSchema = noteCreateSchema.partial();

type NoteBody = z.infer<typeof noteCreateSchema>;

const noteInclude = { tagLinks: { include: { tag: true } } };

type NoteWithLinks = Prisma.NoteGetPayload<{ include: typeof noteInclude }>;

function serializeNote(note: NoteWithLinks) {
  const { tagLinks, ...rest } = note;
  return { ...rest, tags: tagLinks.map((l) => l.tag).filter((t) => !t.deletedAt) };
}

export async function noteRoutes(app: FastifyInstance) {
  app.get('/api/notes', { preHandler: requireAuth }, async (req, reply) => {
    try {
      const q = sinceQuery.parse(req.query);
      const where: Prisma.NoteWhereInput = { userId: req.user.sub };
      if (q.since) {
        const since = new Date(q.since);
        where.OR = [{ updatedAt: { gt: since } }, { deletedAt: { gt: since } }];
      } else {
        where.deletedAt = null;
      }
      const notes = await prisma.note.findMany({
        where,
        include: noteInclude,
        orderBy: { updatedAt: 'asc' },
      });
      return notes.map(serializeNote);
    } catch (err) {
      return handleError(err, reply);
    }
  });

  app.get('/api/notes/:id', { preHandler: requireAuth }, async (req, reply) => {
    try {
      const { id } = z.object({ id: z.string().uuid() }).parse(req.params);
      const note = await prisma.note.findFirst({ where: { id, userId: req.user.sub }, include: noteInclude });
      if (!note) throw new HttpError(404, 'not_found');
      return serializeNote(note);
    } catch (err) {
      return handleError(err, reply);
    }
  });

  app.post('/api/notes', { preHandler: requireAuth }, async (req, reply) => {
    try {
      const body = noteCreateSchema.parse(req.body);
      const note = await prisma.$transaction(async (tx) => {
        const n = await tx.note.create({
          data: {
            id: body.id,
            title: body.title,
            content: body.content,
            pinned: body.pinned,
            archived: body.archived,
            userId: req.user.sub,
          },
        });
        if (body.tagIds?.length) {
          await tx.noteTag.createMany({ data: body.tagIds.map((tagId) => ({ noteId: n.id, tagId })) });
        }
        return n;
      });
      const withTags = await prisma.note.findFirst({ where: { id: note.id }, include: noteInclude });
      return serializeNote(withTags!);
    } catch (err) {
      return handleError(err, reply);
    }
  });

  app.put('/api/notes/:id', { preHandler: requireAuth }, async (req, reply) => {
    try {
      const { id } = z.object({ id: z.string().uuid() }).parse(req.params);
      const body = noteUpdateSchema.parse(req.body);
      const existing = await prisma.note.findFirst({ where: { id, userId: req.user.sub } });
      if (!existing) throw new HttpError(404, 'not_found');

      const data: Prisma.NoteUncheckedUpdateInput = {};
      for (const key of ['title', 'content', 'pinned', 'archived'] as const) {
        if (body[key] !== undefined) (data as Record<string, unknown>)[key] = body[key];
      }
      await prisma.$transaction(async (tx) => {
        await tx.note.update({ where: { id }, data });
        if (body.tagIds !== undefined) {
          await tx.noteTag.deleteMany({ where: { noteId: id } });
          if (body.tagIds.length) {
            await tx.noteTag.createMany({ data: body.tagIds.map((tagId) => ({ noteId: id, tagId })) });
          }
          await tx.note.update({ where: { id }, data: { updatedAt: new Date() } });
        }
      });
      const updated = await prisma.note.findFirst({ where: { id }, include: noteInclude });
      return serializeNote(updated!);
    } catch (err) {
      return handleError(err, reply);
    }
  });

  app.delete('/api/notes/:id', { preHandler: requireAuth }, async (req, reply) => {
    try {
      const { id } = z.object({ id: z.string().uuid() }).parse(req.params);
      const q = sinceQuery.parse(req.query);
      if (q.hard === 'true') {
        const r = await prisma.note.deleteMany({ where: { id, userId: req.user.sub } });
        if (r.count === 0) throw new HttpError(404, 'not_found');
        return { ok: true, hard: true };
      }
      const r = await prisma.note.updateMany({
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
