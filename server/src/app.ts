import Fastify from 'fastify';
import cors from '@fastify/cors';
import { registerAuth } from './auth.js';
import { authRoutes } from './routes/auth.js';
import { tagRoutes } from './routes/tags.js';
import { taskRoutes } from './routes/tasks.js';
import { eventRoutes } from './routes/events.js';
import { noteRoutes } from './routes/notes.js';
import { syncRoutes } from './routes/sync.js';
import { statsRoutes } from './routes/stats.js';

export async function buildApp(opts: { logger?: boolean } = {}) {
  const app = Fastify({ logger: opts.logger ?? false });

  await app.register(cors, { origin: true });
  await registerAuth(app);

  await app.register(authRoutes);
  await app.register(tagRoutes);
  await app.register(taskRoutes);
  await app.register(eventRoutes);
  await app.register(noteRoutes);
  await app.register(syncRoutes);
  await app.register(statsRoutes);

  app.get('/api/health', async () => ({ ok: true, time: new Date().toISOString() }));

  return app;
}
