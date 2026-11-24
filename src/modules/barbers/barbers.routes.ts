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
 * /api/barbers:
 *   get:
 *     tags:
 *       - Barbers
 *     summary: Get all barbers formatted to match Frontend TKapster type
 *     parameters:
 *       - in: query
 *         name: search
 *         schema:
 *           type: string
 *         description: Search by barber name or phone number
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum: [Semua, Aktif, Nonaktif]
 *         description: Filter by active status
 *     responses:
 *       200:
 *         description: List of barbers matching TKapster
 */
router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { search, status } = req.query;

    let query = `
      SELECT 
        b.id,
        b.full_name as name,
        b.phone_number as phone,
        b.specialty,
        b.is_active,
        b.profile_picture_url,
        (SELECT COUNT(*) FROM reviews r WHERE r.barber_id = b.id) as barber_review_count,
        (SELECT ROUND(AVG(r.rating_barber), 1) FROM reviews r WHERE r.barber_id = b.id) as live_rating,
        u.email,
        (SELECT COUNT(*) FROM bookings bk WHERE bk.barber_id = b.id AND bk.status = 'completed') as finished,
        (SELECT COUNT(*) FROM bookings bk WHERE bk.barber_id = b.id AND bk.status = 'completed' AND bk.booking_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)) as weeklyCuts,
        (SELECT COALESCE(SUM(bk.total_price), 0) FROM bookings bk WHERE bk.barber_id = b.id AND bk.status = 'completed' AND bk.booking_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)) as weeklyIncomeRaw
      FROM barbers b
      LEFT JOIN users u ON u.id = b.user_id
      WHERE 1=1
    `;
    const params: any[] = [];

    if (search && typeof search === 'string' && search.trim() !== '') {
      query += ` AND (b.full_name LIKE ? OR b.phone_number LIKE ?)`;
      const term = `%${search.trim()}%`;
      params.push(term, term);
    }

    if (status && typeof status === 'string' && status !== 'Semua') {
      if (status.toLowerCase() === 'aktif') {
        query += ` AND b.is_active = 1`;
      } else if (status.toLowerCase() === 'nonaktif') {
        query += ` AND b.is_active = 0`;
      }
    }

    query += ` ORDER BY b.created_at ASC`;

    const [rows] = await dbPool.query<RowDataPacket[]>(query, params);

    const [counts] = await dbPool.query<RowDataPacket[]>(`
      SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN is_active = 1 THEN 1 ELSE 0 END) as active,
        SUM(CASE WHEN is_active = 0 THEN 1 ELSE 0 END) as inactive
      FROM barbers
    `);

    let inServiceCount = 0;
    let totalRev = 0;
    let avgRat = '0.0';

    try {
      const [extraStats] = await dbPool.query<RowDataPacket[]>(`
        SELECT 
          (SELECT COUNT(*) FROM queues WHERE status = 'in_progress') as inServiceCount,
          (SELECT COUNT(*) FROM reviews) as totalReviews,
          (SELECT ROUND(AVG(rating_barber), 1) FROM reviews) as avgRating
      `);
      inServiceCount = Number(extraStats[0]?.inServiceCount || 0);
      totalRev = Number(extraStats[0]?.totalReviews || 0);
      avgRat = totalRev > 0 && extraStats[0]?.avgRating ? Number(extraStats[0].avgRating).toFixed(1) : '0.0';
    } catch (_err) {
      // safe fallback
    }

    const data = rows.map((b) => {
      const initials = (b.name || '')
        .split(' ')
        .map((p: string) => p[0])
        .join('')
        .slice(0, 2)
        .toUpperCase();

      const rawPhone = b.phone ? String(b.phone).replace(/\D/g, '') : '';
      const formattedIncome = `Rp${Number(b.weeklyIncomeRaw || 0).toLocaleString('id-ID')}`;
      const revCount = Number(b.barber_review_count || 0);
      const ratingVal = revCount > 0 && b.live_rating ? Number(b.live_rating).toFixed(1) : '0.0';

      return {
        id: b.id,
        uuid: b.id,
        phone: b.phone || '',
        rawPhone,
        name: b.name,
        initials,
        specialty: b.specialty || 'General Cut',
        email: b.email || `${b.name.toLowerCase().replace(/\s+/g, '')}@trim.id`,
        finished: Number(b.finished || 0),
        weeklyCuts: Number(b.weeklyCuts || 0),
        weeklyIncome: formattedIncome,
        rating: ratingVal,
        totalReviews: revCount,
        status: b.is_active ? 'aktif' : 'nonaktif',
        statusText: b.is_active ? 'Aktif' : 'Nonaktif',
        badgeType: b.is_active ? 'success' : 'muted',
        imageUrl: b.profile_picture_url || undefined,
      };
    });

    const meta = {
      totalCount: Number(counts[0]?.total || 0),
      activeCount: Number(counts[0]?.active || 0),
      inactiveCount: Number(counts[0]?.inactive || 0),
      inServiceCount,
      averageRating: avgRat,
      totalReviews: totalRev,
    };

    return sendSuccess(res, data, 'OK', 200, meta);
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/barbers/{id}:
 *   get:
 *     tags:
 *       - Barbers
 *     summary: Get single barber detail
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Barber detail matching TKapster
 */
router.get('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;

    const [rows] = await dbPool.query<RowDataPacket[]>(
      `SELECT 
        b.id,
        b.full_name as name,
        b.phone_number as phone,
        b.specialty,
        b.is_active,
        b.profile_picture_url,
        (SELECT COUNT(*) FROM reviews r WHERE r.barber_id = b.id) as barber_review_count,
        (SELECT ROUND(AVG(r.rating_barber), 1) FROM reviews r WHERE r.barber_id = b.id) as live_rating,
        b.experience_years,
        b.created_at,
        u.email,
        (SELECT COUNT(*) FROM bookings bk WHERE bk.barber_id = b.id AND bk.status = 'completed') as finished,
        (SELECT COUNT(*) FROM bookings bk WHERE bk.barber_id = b.id AND bk.status = 'completed' AND bk.booking_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)) as weeklyCuts,
        (SELECT COALESCE(SUM(bk.total_price), 0) FROM bookings bk WHERE bk.barber_id = b.id AND bk.status = 'completed' AND bk.booking_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)) as weeklyIncomeRaw
      FROM barbers b
      LEFT JOIN users u ON u.id = b.user_id
      WHERE b.id = ? OR b.phone_number = ?
      LIMIT 1`,
      [id, id]
    );

    if (rows.length === 0) throw new AppError('Kapster tidak ditemukan', 404);

    const b = rows[0];
    const initials = (b.name || '')
      .split(' ')
      .map((p: string) => p[0])
      .join('')
      .slice(0, 2)
      .toUpperCase();

    const rawPhone = b.phone ? String(b.phone).replace(/\D/g, '') : '';
    const formattedIncome = `Rp${Number(b.weeklyIncomeRaw || 0).toLocaleString('id-ID')}`;
    const revCount = Number(b.barber_review_count || 0);
    const ratingVal = revCount > 0 && b.live_rating ? Number(b.live_rating).toFixed(1) : '0.0';

    return sendSuccess(res, {
      id: b.id,
      uuid: b.id,
      phone: b.phone || '',
      rawPhone,
      name: b.name,
      initials,
      specialty: b.specialty || 'General Cut',
      email: b.email || `${b.name.toLowerCase().replace(/\s+/g, '')}@trim.id`,
      finished: Number(b.finished || 0),
      weeklyCuts: Number(b.weeklyCuts || 0),
      weeklyIncome: formattedIncome,
      rating: ratingVal,
      totalReviews: revCount,
      experienceYears: Number(b.experience_years || 1),
      status: b.is_active ? 'aktif' : 'nonaktif',
      statusText: b.is_active ? 'Aktif' : 'Nonaktif',
      badgeType: b.is_active ? 'success' : 'muted',
      imageUrl: b.profile_picture_url || undefined,
      createdAt: b.created_at,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/barbers:
 *   post:
 *     tags:
 *       - Barbers
 *     summary: Create new barber
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
 *                 example: Ahmad Dani
 *               phone:
 *                 type: string
 *                 example: 081234567890
 *               specialty:
 *                 type: string
 *                 example: Fade & Taper
 *               isActive:
 *                 type: boolean
 *                 default: true
 *     responses:
 *       201:
 *         description: Barber created successfully
 *       400:
 *         description: Validation error
 */
router.post('/', authenticate, authorize('owner', 'admin'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { name, phone, specialty, isActive = true } = req.body;
    if (!name) {
      throw new AppError('Nama kapster wajib diisi', 400);
    }

    const barberId = crypto.randomUUID();
    const userId = crypto.randomUUID();
    const cleanName = (name || 'barber').toLowerCase().replace(/[^a-z0-9]/g, '');
    const barberEmail = `${cleanName || 'barber'}-${Date.now().toString(36)}@trim.id`;

    // Create user record for auth link
    await dbPool.query(
      `INSERT INTO users (id, email, password_hash, role)
       VALUES (?, ?, '$2a$12$e8yM2dK5WvA8qKqj8/5Gzeu0uXk7n0Xk8vK3/b1q7w6YdC6Vf2d2i', 'barber')`,
      [userId, barberEmail]
    );

    await dbPool.query(
      `INSERT INTO barbers (id, user_id, full_name, phone_number, specialty, experience_years, is_active, average_rating, total_reviews)
       VALUES (?, ?, ?, ?, ?, 1, ?, 0.0, 0)`,
      [barberId, userId, name, phone || null, specialty || 'General Cut', isActive ? 1 : 0]
    );

    return sendSuccess(res, { id: barberId, name, phone, specialty }, 'Kapster berhasil ditambahkan', 201);
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/barbers/{id}:
 *   put:
 *     tags:
 *       - Barbers
 *     summary: Update barber details
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
 *               phone:
 *                 type: string
 *               specialty:
 *                 type: string
 *               isActive:
 *                 type: boolean
 *     responses:
 *       200:
 *         description: Barber updated successfully
 *       404:
 *         description: Barber not found
 */
router.put('/:id', authenticate, authorize('owner', 'admin'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const { name, phone, specialty, isActive } = req.body;

    const [result] = await dbPool.query<ResultSetHeader>(
      `UPDATE barbers 
       SET full_name = COALESCE(?, full_name),
           phone_number = COALESCE(?, phone_number),
           specialty = COALESCE(?, specialty),
           is_active = COALESCE(?, is_active)
       WHERE id = ?`,
      [name, phone, specialty, typeof isActive === 'boolean' ? (isActive ? 1 : 0) : null, id]
    );

    if (result.affectedRows === 0) {
      throw new AppError('Kapster tidak ditemukan', 404);
    }

    return sendSuccess(res, { id }, 'Data kapster berhasil diperbarui');
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/barbers/{id}:
 *   delete:
 *     tags:
 *       - Barbers
 *     summary: Delete a barber (or mark inactive if related bookings exist)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Barber deleted or deactivated successfully
 */
router.delete('/:id', authenticate, authorize('owner', 'admin'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;

    // Check if barber exists
    const [barbers] = await dbPool.query<RowDataPacket[]>('SELECT id, full_name FROM barbers WHERE id = ?', [id]);
    if (barbers.length === 0) throw new AppError('Kapster tidak ditemukan', 404);

    // Try deleting; if foreign key restricts (e.g. historical bookings), fallback to soft-delete
    try {
      await dbPool.query('DELETE FROM barbers WHERE id = ?', [id]);
      return sendSuccess(res, { id }, `Kapster "${barbers[0].full_name}" berhasil dihapus`);
    } catch (_err) {
      await dbPool.query('UPDATE barbers SET is_active = 0 WHERE id = ?', [id]);
      return sendSuccess(res, { id, is_active: 0 }, `Kapster memiliki riwayat booking, status diubah menjadi Nonaktif`);
    }
  } catch (error) {
    next(error);
  }
});

export default router;
