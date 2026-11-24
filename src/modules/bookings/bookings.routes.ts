import { Router, Request, Response, NextFunction } from 'express';
import { dbPool } from '../../config/db';
import { sendSuccess } from '../../utils/response';
import { AppError } from '../../utils/AppError';
import { RowDataPacket } from 'mysql2';
import crypto from 'crypto';

const router = Router();

/**
 * @openapi
 * /api/bookings:
 *   get:
 *     tags:
 *       - Bookings
 *     summary: Get all bookings with date, barber, and status filters
 *     parameters:
 *       - in: query
 *         name: date
 *         schema:
 *           type: string
 *         description: Format YYYY-MM-DD
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum: [all, pending, confirmed, checked_in, in_queue, in_service, completed, cancelled, no_show]
 *       - in: query
 *         name: barberId
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: List of bookings
 */
router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { date, status, barberId } = req.query;

    let query = `
      SELECT 
        b.id, b.customer_id, b.barber_id, b.booking_date, b.start_time, b.end_time,
        b.status, b.total_price, b.created_at,
        c.full_name as customer_name, c.phone_number as customer_phone,
        br.full_name as barber_name,
        (SELECT GROUP_CONCAT(s.name SEPARATOR ', ') 
         FROM booking_services bs 
         JOIN services s ON s.id = bs.service_id 
         WHERE bs.booking_id = b.id) as services
      FROM bookings b
      LEFT JOIN customers c ON c.id = b.customer_id
      LEFT JOIN barbers br ON br.id = b.barber_id
      WHERE 1=1
    `;
    const params: any[] = [];

    if (date && typeof date === 'string') {
      query += ` AND b.booking_date = ?`;
      params.push(date);
    }
    if (status && typeof status === 'string' && status !== 'all') {
      query += ` AND b.status = ?`;
      params.push(status);
    }
    if (barberId && typeof barberId === 'string' && barberId !== 'all') {
      query += ` AND b.barber_id = ?`;
      params.push(barberId);
    }

    query += ` ORDER BY b.booking_date DESC, b.start_time DESC`;

    const [rows] = await dbPool.query<RowDataPacket[]>(query, params);
    return sendSuccess(res, rows, 'OK', 200, { totalCount: rows.length });
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/bookings:
 *   post:
 *     tags:
 *       - Bookings
 *     summary: Create new booking appointment
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - barberId
 *               - bookingDate
 *               - startTime
 *               - serviceIds
 *             properties:
 *               customerId:
 *                 type: string
 *               barberId:
 *                 type: string
 *               bookingDate:
 *                 type: string
 *                 format: date
 *                 example: "2026-11-20"
 *               startTime:
 *                 type: string
 *                 example: "14:00"
 *               serviceIds:
 *                 type: array
 *                 items:
 *                   type: string
 *     responses:
 *       201:
 *         description: Booking appointment created successfully
 *       400:
 *         description: Incomplete booking data
 */
router.post('/', async (req: Request, res: Response, next: NextFunction) => {
  const conn = await dbPool.getConnection();
  try {
    const { customerId, barberId, bookingDate, startTime, serviceIds } = req.body;

    if (!barberId || !bookingDate || !startTime || !Array.isArray(serviceIds) || serviceIds.length === 0) {
      throw new AppError('Data reservasi tidak lengkap (barberId, bookingDate, startTime, serviceIds wajib diisi)', 400);
    }

    await conn.beginTransaction();

    // Default customer if not passed (e.g. walk-in booking)
    let cId = customerId;
    if (!cId) {
      const [custRows] = await conn.query<RowDataPacket[]>('SELECT id FROM customers LIMIT 1');
      cId = custRows[0]?.id;
    }

    // Calculate total price & duration from services
    const [services] = await conn.query<RowDataPacket[]>(
      'SELECT id, price, duration_minutes FROM services WHERE id IN (?)',
      [serviceIds]
    );

    let totalPrice = 0;
    let totalDuration = 0;
    services.forEach((s) => {
      totalPrice += Number(s.price || 0);
      totalDuration += Number(s.duration_minutes || 30);
    });

    const bookingId = crypto.randomUUID();
    const bookingCode = `TRIM-${Date.now().toString(36).toUpperCase()}`;
    const [startH, startM] = startTime.split(':').map(Number);
    const endMinutesTotal = ((startH || 0) * 60 + (startM || 0)) + totalDuration;
    const endH = Math.floor(endMinutesTotal / 60) % 24;
    const endM = endMinutesTotal % 60;
    const endTime = `${String(endH).padStart(2, '0')}:${String(endM).padStart(2, '0')}:00`;

    // Insert booking
    await conn.query(
      `INSERT INTO bookings (id, booking_code, customer_id, barber_id, booking_date, start_time, end_time, status, total_price)
       VALUES (?, ?, ?, ?, ?, ?, ?, 'confirmed', ?)`,
      [bookingId, bookingCode, cId, barberId, bookingDate, startTime, endTime, totalPrice]
    );

    // Insert booking_services
    for (const s of services) {
      await conn.query(
        `INSERT INTO booking_services (id, booking_id, service_id, price_at_booking)
         VALUES (UUID(), ?, ?, ?)`,
        [bookingId, s.id, s.price]
      );
    }

    await conn.commit();

    return sendSuccess(res, { bookingId, totalPrice, totalDuration, status: 'confirmed' }, 'Booking berhasil dibuat', 201);
  } catch (error) {
    await conn.rollback();
    next(error);
  } finally {
    conn.release();
  }
});

/**
 * @openapi
 * /api/bookings/{id}/status:
 *   patch:
 *     tags:
 *       - Bookings
 *     summary: Update booking status
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - status
 *             properties:
 *               status:
 *                 type: string
 *                 enum: [pending, confirmed, checked_in, in_queue, in_service, completed, cancelled, no_show]
 *     responses:
 *       200:
 *         description: Booking status updated successfully
 *       404:
 *         description: Booking not found
 */
router.patch('/:id/status', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    if (!status) throw new AppError('status wajib diisi', 400);

    const [result]: any = await dbPool.query(
      'UPDATE bookings SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      [status, id]
    );

    if (result.affectedRows === 0) {
      throw new AppError('Booking tidak ditemukan', 404);
    }

    return sendSuccess(res, { id, status }, 'Status booking berhasil diupdate');
  } catch (error) {
    next(error);
  }
});

export default router;

