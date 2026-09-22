import type { FastifyReply } from 'fastify';
import { ZodError } from 'zod';

export class HttpError extends Error {
  constructor(
    public statusCode: number,
    message: string,
  ) {
    super(message);
  }
}

/** 统一错误处理：Zod 校验错误 → 400，业务错误 → 对应状态码 */
export function handleError(err: unknown, reply: FastifyReply) {
  if (err instanceof ZodError) {
    return reply.code(400).send({ error: 'validation_error', details: err.flatten() });
  }
  if (err instanceof HttpError) {
    return reply.code(err.statusCode).send({ error: err.message });
  }
  // Prisma 已知错误码
  const code = (err as { code?: string })?.code;
  if (code === 'P2002') {
    return reply.code(409).send({ error: 'already_exists' });
  }
  if (code === 'P2025') {
    return reply.code(404).send({ error: 'not_found' });
  }
  console.error('[unhandled error]', err);
  return reply.code(500).send({ error: 'internal_error' });
}
