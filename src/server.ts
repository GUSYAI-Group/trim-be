import app from './app';
import { env } from './config/env';
import { dbPool } from './config/db';

const server = app.listen(env.port, () => {
  console.log(`[trim-be] Server running on http://localhost:${env.port}`);
  console.log(`[trim-be] Swagger UI available at http://localhost:${env.port}/api-docs`);
});

async function shutdown(signal: string): Promise<void> {
  console.log(`[trim-be] ${signal} received, shutting down gracefully...`);
  server.close(async () => {
    await dbPool.end();
    process.exit(0);
  });
}

process.on('SIGINT', () => void shutdown('SIGINT'));
process.on('SIGTERM', () => void shutdown('SIGTERM'));

