import type { FastifyInstance, FastifyRequest } from 'fastify';
import jwtPlugin from '@fastify/jwt';
import { HttpError } from './errors.js';
import { config } from './config.js';

declare module '@fastify/jwt' {
  interface FastifyJWT {
    payload: { sub: string; email: string; type: 'access' | 'refresh' };
    user: { sub: string; email: string; type: 'access' | 'refresh' };
  }
}

export async function registerAuth(app: FastifyInstance) {
  await app.register(jwtPlugin, { secret: config.jwtSecret });
}

/** preHandler：要求合法 access token */
export async function requireAuth(request: FastifyRequest) {
  try {
    await request.jwtVerify();
  } catch {
    throw new HttpError(401, 'unauthorized');
  }
  if (request.user.type !== 'access') {
    throw new HttpError(401, 'unauthorized');
  }
}

export function issueTokens(app: FastifyInstance, userId: string, email: string) {
  const accessToken = app.jwt.sign(
    { sub: userId, email, type: 'access' },
    { expiresIn: config.accessTtl },
  );
  const refreshToken = app.jwt.sign(
    { sub: userId, email, type: 'refresh' },
    { expiresIn: config.refreshTtl },
  );
  return { accessToken, refreshToken };
}
