import { Router, Request, Response, NextFunction } from 'express';
import { dbPool } from '../../config/db';
import { sendSuccess } from '../../utils/response';
import { RowDataPacket } from 'mysql2';
import { authenticate, authorize } from '../../middlewares/auth';

const router = Router();

/**
 * @openapi
 * /api/settings:
 *   get:
 *     tags:
 *       - Settings
 *     summary: Get all store configuration & operational settings
 */
router.get('/', async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const [rows] = await dbPool.query<RowDataPacket[]>('SELECT setting_key, setting_value, description FROM store_settings');
    const settingsMap: Record<string, string> = {};
    rows.forEach((r) => {
      settingsMap[r.setting_key] = r.setting_value;
    });

    return sendSuccess(res, {
      settings: settingsMap,
      raw: rows,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/settings:
 *   put:
 *     tags:
 *       - Settings
 *     summary: Update store configuration
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             additionalProperties:
 *               type: string
 *             example:
 *               store_name: TRIM Barbershop Premium
 *               open_hour: "09:00"
 *               close_hour: "21:00"
 *     responses:
 *       200:
 *         description: Settings updated successfully
 */
router.put('/', authenticate, authorize('owner', 'admin'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const updates = req.body; // { key: value }
    for (const [key, value] of Object.entries(updates)) {
      await dbPool.query(
        `INSERT INTO store_settings (setting_key, setting_value, description)
         VALUES (?, ?, '')
         ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value)`,
        [key, String(value)]
      );
    }
    return sendSuccess(res, updates, 'Pengaturan toko berhasil diperbarui');
  } catch (error) {
    next(error);
  }
});

export default router;

