import type { FastifyInstance } from 'fastify';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { prisma } from '../db.js';
import { HttpError, handleError } from '../errors.js';
import { issueTokens, requireAuth } from '../auth.js';

const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8).max(72),
  displayName: z.string().max(50).optional(),
});
const loginSchema = z.object({
  email: z.string().email(),
  password: z.string(),
});
const refreshSchema = z.object({ refreshToken: z.string().min(1) });

function publicUser(user: { id: string; email: string; displayName: string | null; createdAt: Date }) {
  return { id: user.id, email: user.email, displayName: user.displayName, createdAt: user.createdAt };
}

export async function authRoutes(app: FastifyInstance) {
  // 注册
  app.post('/api/auth/register', async (req, reply) => {
    try {
      const body = registerSchema.parse(req.body);
      const passwordHash = await bcrypt.hash(body.password, 10);
      const user = await prisma.user.create({
        data: { email: body.email.toLowerCase(), passwordHash, displayName: body.displayName },
      });
      return { user: publicUser(user), ...issueTokens(app, user.id, user.email) };
    } catch (err) {
      return handleError(err, reply);
    }
  });

  // 登录
  app.post('/api/auth/login', async (req, reply) => {
    try {
      const body = loginSchema.parse(req.body);
      const user = await prisma.user.findUnique({ where: { email: body.email.toLowerCase() } });
      if (!user || !(await bcrypt.compare(body.password, user.passwordHash))) {
        throw new HttpError(401, 'invalid_credentials');
      }
      return { user: publicUser(user), ...issueTokens(app, user.id, user.email) };
    } catch (err) {
      return handleError(err, reply);
    }
  });

  // 刷新令牌（换取新的 access + refresh）
  app.post('/api/auth/refresh', async (req, reply) => {
    try {
      const { refreshToken } = refreshSchema.parse(req.body);
      let payload: { sub: string; email: string; type: string };
      try {
        payload = app.jwt.verify(refreshToken);
      } catch {
        throw new HttpError(401, 'invalid_refresh_token');
      }
      if (payload.type !== 'refresh') {
        throw new HttpError(401, 'invalid_refresh_token');
      }
      const user = await prisma.user.findUnique({ where: { id: payload.sub } });
      if (!user) {
        throw new HttpError(401, 'invalid_refresh_token');
      }
      return issueTokens(app, user.id, user.email);
    } catch (err) {
      return handleError(err, reply);
    }
  });

  // 登出（v1 为无状态方案：客户端丢弃令牌即可；服务端预留撤销扩展点）
  app.post('/api/auth/logout', async () => ({ ok: true }));

  // 当前用户信息
  app.get('/api/me', { preHandler: requireAuth }, async (req, reply) => {
    try {
      const user = await prisma.user.findUnique({ where: { id: req.user.sub } });
      if (!user) throw new HttpError(404, 'not_found');
      return publicUser(user);
    } catch (err) {
      return handleError(err, reply);
    }
  });
}
