import { Router, Request, Response } from 'express';
import { testDbConnection } from '../../config/db';
import { sendSuccess } from '../../utils/response';

const router = Router();

/**
 * @openapi
 * /api/health:
 *   get:
 *     tags:
 *       - System
 *     summary: Health check endpoint
 *     description: Checks whether the Express server is running and tests Neon PostgreSQL connectivity.
 *     responses:
 *       200:
 *         description: Server is healthy
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 message:
 *                   type: string
 *                   example: Service is healthy
 *                 data:
 *                   type: object
 *                   properties:
 *                     status:
 *                       type: string
 *                       example: ok
 *                     database:
 *                       type: string
 *                       example: connected
 *                     uptimeSeconds:
 *                       type: number
 *                       example: 12.34
 *                     timestamp:
 *                       type: string
 *                       format: date-time
 */
router.get('/', async (_req: Request, res: Response) => {
  let dbStatus: 'connected' | 'disconnected' = 'disconnected';
  let dbError: string | undefined;

  try {
    await testDbConnection();
    dbStatus = 'connected';
  } catch (error) {
    dbError = error instanceof Error ? error.message : 'Unknown database error';
  }

  return sendSuccess(
    res,
    {
      status: 'ok',
      database: dbStatus,
      databaseType: 'PostgreSQL (Neon)',
      ...(dbError ? { dbError } : {}),
      uptimeSeconds: Number(process.uptime().toFixed(2)),
      timestamp: new Date().toISOString(),
    },
    'Service is healthy'
  );
});

export default router;

