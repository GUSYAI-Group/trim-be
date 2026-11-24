import { Router, Request, Response, NextFunction } from 'express';
import { dbPool } from '../../config/db';
import { sendSuccess } from '../../utils/response';
import { AppError } from '../../utils/AppError';
import { RowDataPacket, ResultSetHeader } from 'mysql2';
import crypto from 'crypto';
import { authenticate, authorize } from '../../middlewares/auth';

const router = Router();

/**
 * @openapi
 * /api/services:
 *   get:
 *     tags:
 *       - Services
 *     summary: Get all haircut & grooming services formatted matching Frontend TService
 *     parameters:
 *       - in: query
 *         name: search
 *         schema:
 *           type: string
 *         description: Search by service name
 *       - in: query
 *         name: category
 *         schema:
 *           type: string
 *         description: Filter by category (e.g. Potong rambut, Paket, Perawatan, Styling, Pewarnaan)
 *     responses:
 *       200:
 *         description: List of services
 */
router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { search, category } = req.query;

    let query = `
      SELECT id, name, category, duration_minutes as duration, price, is_active
      FROM services
      WHERE 1=1
    `;
    const params: any[] = [];

    if (search && typeof search === 'string' && search.trim() !== '') {
      query += ` AND name LIKE ?`;
      params.push(`%${search.trim()}%`);
    }

    if (category && typeof category === 'string' && category !== 'Semua' && category !== 'all') {
      query += ` AND category = ?`;
      params.push(category);
    }

    query += ` ORDER BY name ASC`;

    const [rows] = await dbPool.query<RowDataPacket[]>(query, params);

    let activeCount = 0;
    let avgDuration = 0;
    let popularServiceName = 'Belum ada data';
    let popularServiceBookings = 0;

    try {
      const [stats] = await dbPool.query<RowDataPacket[]>(`
        SELECT 
          (SELECT COUNT(*) FROM services WHERE is_active = 1) as activeCount,
          (SELECT ROUND(COALESCE(AVG(duration_minutes), 0)) FROM services WHERE is_active = 1) as avgDuration
      `);
      activeCount = Number(stats[0]?.activeCount || 0);
      avgDuration = Number(stats[0]?.avgDuration || 0);

      const [popRows] = await dbPool.query<RowDataPacket[]>(`
        SELECT s.name, COUNT(bs.service_id) as total_booked
        FROM booking_services bs 
        JOIN services s ON s.id = bs.service_id 
        GROUP BY s.id, s.name 
        ORDER BY total_booked DESC, s.name ASC 
        LIMIT 1
      `);
      if (popRows.length > 0 && Number(popRows[0].total_booked || 0) > 0) {
        popularServiceName = String(popRows[0].name);
        popularServiceBookings = Number(popRows[0].total_booked);
      }
    } catch (_err) {
      // safe fallback
    }

    const data = rows.map((s) => {
      const priceNum = Number(s.price || 0);
      return {
        id: s.id,
        name: s.name,
        category: s.category,
        duration: Number(s.duration || 30),
        price: priceNum,
        priceFormatted: priceNum.toLocaleString('id-ID'),
        isActive: Boolean(s.is_active),
      };
    });

    return sendSuccess(res, data, 'OK', 200, {
      totalCount: data.length,
      activeCount,
      avgDuration,
      popularServiceName,
      popularServiceBookings,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/services/{id}:
 *   get:
 *     tags:
 *       - Services
 *     summary: Get single service detail
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Service detail
 */
router.get('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const [rows] = await dbPool.query<RowDataPacket[]>(
      `SELECT id, name, category, duration_minutes as duration, price, is_active
       FROM services WHERE id = ? LIMIT 1`,
      [id]
    );

    if (rows.length === 0) throw new AppError('Layanan tidak ditemukan', 404);

    const s = rows[0];
    const priceNum = Number(s.price || 0);

    return sendSuccess(res, {
      id: s.id,
      name: s.name,
      category: s.category,
      duration: Number(s.duration || 30),
      price: priceNum,
      priceFormatted: priceNum.toLocaleString('id-ID'),
      isActive: Boolean(s.is_active),
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/services:
 *   post:
 *     tags:
 *       - Services
 *     summary: Add new service
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - name
 *             properties:
 *               name:
 *                 type: string
 *                 example: Fade Premium
 *               category:
 *                 type: string
 *                 default: Potong rambut
 *               duration:
 *                 type: integer
 *                 default: 30
 *               price:
 *                 type: number
 *                 default: 50000
 *               isActive:
 *                 type: boolean
 *                 default: true
 *     responses:
 *       201:
 *         description: Service created successfully
 *       400:
 *         description: Validation error
 */
router.post('/', authenticate, authorize('owner', 'admin'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { name, category = 'Potong rambut', duration = 30, price = 0, isActive = true } = req.body;
    if (!name) throw new AppError('Nama layanan wajib diisi', 400);

    const serviceId = crypto.randomUUID();
    await dbPool.query(
      `INSERT INTO services (id, name, category, duration_minutes, price, is_active)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [serviceId, name, category, duration, price, isActive ? 1 : 0]
    );

    return sendSuccess(res, { id: serviceId, name, price }, 'Layanan berhasil dibuat', 201);
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/services/{id}:
 *   put:
 *     tags:
 *       - Services
 *     summary: Update existing service
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *               category:
 *                 type: string
 *               duration:
 *                 type: integer
 *               price:
 *                 type: number
 *               isActive:
 *                 type: boolean
 *     responses:
 *       200:
 *         description: Service updated successfully
 *       404:
 *         description: Service not found
 */
router.put('/:id', authenticate, authorize('owner', 'admin'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const { name, category, duration, price, isActive } = req.body;

    const [resHeader] = await dbPool.query<ResultSetHeader>(
      `UPDATE services
       SET name = COALESCE(?, name),
           category = COALESCE(?, category),
           duration_minutes = COALESCE(?, duration_minutes),
           price = COALESCE(?, price),
           is_active = COALESCE(?, is_active)
       WHERE id = ?`,
      [name, category, duration, price, typeof isActive === 'boolean' ? (isActive ? 1 : 0) : null, id]
    );

    if (resHeader.affectedRows === 0) throw new AppError('Layanan tidak ditemukan', 404);

    return sendSuccess(res, { id }, 'Layanan berhasil diperbarui');
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/services/{id}:
 *   delete:
 *     tags:
 *       - Services
 *     summary: Delete a service (or mark inactive if related bookings exist)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Service deleted or deactivated successfully
 */
router.delete('/:id', authenticate, authorize('owner', 'admin'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;

    const [services] = await dbPool.query<RowDataPacket[]>('SELECT id, name FROM services WHERE id = ?', [id]);
    if (services.length === 0) throw new AppError('Layanan tidak ditemukan', 404);

    try {
      await dbPool.query('DELETE FROM services WHERE id = ?', [id]);
      return sendSuccess(res, { id }, `Layanan "${services[0].name}" berhasil dihapus`);
    } catch (_err) {
      await dbPool.query('UPDATE services SET is_active = 0 WHERE id = ?', [id]);
      return sendSuccess(res, { id, is_active: 0 }, `Layanan terkait dengan riwayat booking, status diubah menjadi Nonaktif`);
    }
  } catch (error) {
    next(error);
  }
});

export default router;
