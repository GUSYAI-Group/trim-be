import { Router, Request, Response, NextFunction } from 'express';
import { dbPool } from '../../config/db';
import { sendSuccess } from '../../utils/response';
import { AppError } from '../../utils/AppError';
import { RowDataPacket } from 'mysql2';
import crypto from 'crypto';

const router = Router();

/**
 * @openapi
 * /api/reviews:
 *   get:
 *     tags:
 *       - Reviews
 *     summary: Get barber and service reviews
 *     parameters:
 *       - in: query
 *         name: barberId
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: List of customer reviews
 */
router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { barberId } = req.query;

    let query = `
      SELECT 
        r.id, r.booking_id, r.rating_barber, r.rating_service, r.review_text, r.created_at,
        c.full_name as customer_name,
        b.full_name as barber_name
      FROM reviews r
      LEFT JOIN customers c ON c.id = r.customer_id
      LEFT JOIN barbers b ON b.id = r.barber_id
      WHERE 1=1
    `;
    const params: any[] = [];

    if (barberId && typeof barberId === 'string') {
      query += ` AND r.barber_id = ?`;
      params.push(barberId);
    }

    query += ` ORDER BY r.created_at DESC`;

    const [rows] = await dbPool.query<RowDataPacket[]>(query, params);
    return sendSuccess(res, rows, 'OK', 200, { totalCount: rows.length });
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/reviews:
 *   post:
 *     tags:
 *       - Reviews
 *     summary: Post a haircut & barber review
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - bookingId
 *               - barberId
 *               - ratingBarber
 *             properties:
 *               bookingId:
 *                 type: string
 *               barberId:
 *                 type: string
 *               customerId:
 *                 type: string
 *               ratingBarber:
 *                 type: number
 *                 minimum: 1
 *                 maximum: 5
 *                 example: 5
 *               ratingService:
 *                 type: number
 *                 minimum: 1
 *                 maximum: 5
 *                 example: 5
 *               reviewText:
 *                 type: string
 *                 example: Pelayanan sangat rapi dan ramah!
 *     responses:
 *       201:
 *         description: Review submitted successfully
 *       400:
 *         description: Validation error
 */
router.post('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { bookingId, barberId, customerId, ratingBarber, ratingService, reviewText } = req.body;

    if (!bookingId || !barberId || !ratingBarber) {
      throw new AppError('bookingId, barberId, dan ratingBarber wajib diisi', 400);
    }

    const reviewId = crypto.randomUUID();
    await dbPool.query(
      `INSERT INTO reviews (id, booking_id, customer_id, barber_id, rating_barber, rating_service, review_text)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [reviewId, bookingId, customerId || null, barberId, ratingBarber, ratingService || ratingBarber, reviewText || '']
    );

    // Update average rating on barber profile
    const [avgRows] = await dbPool.query<RowDataPacket[]>(
      'SELECT AVG(rating_barber) as avgRating, COUNT(*) as cnt FROM reviews WHERE barber_id = ?',
      [barberId]
    );

    if (avgRows.length > 0) {
      await dbPool.query(
        'UPDATE barbers SET average_rating = ?, total_reviews = ? WHERE id = ?',
        [Number(avgRows[0].avgRating || 5.0).toFixed(2), avgRows[0].cnt, barberId]
      );
    }

    return sendSuccess(res, { reviewId }, 'Ulasan berhasil disimpan', 201);
  } catch (error) {
    next(error);
  }
});

export default router;

