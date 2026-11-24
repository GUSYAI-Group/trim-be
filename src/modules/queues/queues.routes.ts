import { Router, Request, Response, NextFunction } from 'express';
import { dbPool } from '../../config/db';
import { sendSuccess } from '../../utils/response';
import { AppError } from '../../utils/AppError';
import { RowDataPacket, ResultSetHeader } from 'mysql2';
import crypto from 'crypto';

const router = Router();

/**
 * @openapi
 * /api/queues:
 *   get:
 *     tags:
 *       - Queues
 *     summary: Get live queue list with status, date, and barber filters
 *     parameters:
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum: [all, waiting, in_progress, completed, skipped]
 *       - in: query
 *         name: date
 *         schema:
 *           type: string
 *         description: Date formatted YYYY-MM-DD
 *       - in: query
 *         name: barberId
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Queue items
 */
router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { status, date, barberId } = req.query;

    let query = `
      SELECT 
        q.id as queue_id,
        q.queue_number,
        q.status as queue_status,
        q.estimated_wait_time_mins,
        q.joined_at,
        b.id as booking_id,
        b.booking_date,
        b.start_time,
        b.status as booking_status,
        b.total_price,
        c.full_name as customer_name,
        c.phone_number as customer_phone,
        br.id as barber_id,
        br.full_name as barber_name,
        (SELECT GROUP_CONCAT(s.name SEPARATOR ', ') 
         FROM booking_services bs 
         JOIN services s ON s.id = bs.service_id 
         WHERE bs.booking_id = b.id) as services
      FROM queues q
      JOIN bookings b ON b.id = q.booking_id
      LEFT JOIN customers c ON c.id = b.customer_id
      LEFT JOIN barbers br ON br.id = b.barber_id
      WHERE 1=1
    `;
    const params: any[] = [];

    if (status && typeof status === 'string' && status !== 'all') {
      query += ` AND q.status = ?`;
      params.push(status);
    }

    if (date && typeof date === 'string') {
      query += ` AND b.booking_date = ?`;
      params.push(date);
    }

    if (barberId && typeof barberId === 'string' && barberId !== 'all') {
      query += ` AND b.barber_id = ?`;
      params.push(barberId);
    }

    query += ` ORDER BY q.joined_at ASC`;

    const [rows] = await dbPool.query<RowDataPacket[]>(query, params);
    return sendSuccess(res, rows, 'OK', 200, { totalCount: rows.length });
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/queues/check-in:
 *   post:
 *     tags:
 *       - Queues
 *     summary: Customer arrives at barbershop, generates queue number
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - bookingId
 *             properties:
 *               bookingId:
 *                 type: string
 *     responses:
 *       201:
 *         description: Check-in successful, queue number assigned
 *       404:
 *         description: Booking not found
 */
router.post('/check-in', async (req: Request, res: Response, next: NextFunction) => {
  const conn = await dbPool.getConnection();
  try {
    const { bookingId } = req.body;
    if (!bookingId) throw new AppError('bookingId wajib diisi', 400);

    await conn.beginTransaction();

    const [booking] = await conn.query<RowDataPacket[]>(
      'SELECT id, status, booking_date FROM bookings WHERE id = ? FOR UPDATE',
      [bookingId]
    );
    if (booking.length === 0) {
      await conn.rollback();
      throw new AppError('Booking tidak ditemukan', 404);
    }

    const [existingQueue] = await conn.query<RowDataPacket[]>(
      'SELECT id, queue_number, status FROM queues WHERE booking_id = ? FOR UPDATE',
      [bookingId]
    );
    if (existingQueue.length > 0) {
      await conn.commit();
      return sendSuccess(res, existingQueue[0], 'Pelanggan sudah terdaftar di antrian');
    }

    // Generate queue number like A-001, A-002 for today
    const [todayCount] = await conn.query<RowDataPacket[]>(
      'SELECT COUNT(*) as cnt FROM queues WHERE DATE(joined_at) = CURDATE() FOR UPDATE'
    );
    const nextSeq = String(Number(todayCount[0]?.cnt || 0) + 1).padStart(3, '0');
    const queueNumber = `A-${nextSeq}`;

    const queueId = crypto.randomUUID();
    await conn.query(
      `INSERT INTO queues (id, booking_id, queue_number, estimated_wait_time_mins, status)
       VALUES (?, ?, ?, 15, 'waiting')`,
      [queueId, bookingId, queueNumber]
    );

    await conn.query("UPDATE bookings SET status = 'in_queue' WHERE id = ?", [bookingId]);

    await conn.commit();

    return sendSuccess(res, { queueId, queueNumber, status: 'waiting' }, 'Check-in berhasil, nomor antrian diterbitkan', 201);
  } catch (error) {
    await conn.rollback();
    next(error);
  } finally {
    conn.release();
  }
});

/**
 * @openapi
 * /api/queues/{id}/status:
 *   patch:
 *     tags:
 *       - Queues
 *     summary: Update queue Kanban status (waiting -> in_progress -> completed / skipped)
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
 *                 enum: [waiting, in_progress, completed, skipped]
 *     responses:
 *       200:
 *         description: Queue status updated successfully
 *       404:
 *         description: Queue not found
 */
router.patch('/:id/status', async (req: Request, res: Response, next: NextFunction) => {
  const conn = await dbPool.getConnection();
  try {
    const { id } = req.params;
    const { status } = req.body; // 'waiting', 'in_progress', 'completed', 'skipped'

    if (!['waiting', 'in_progress', 'completed', 'skipped'].includes(status)) {
      throw new AppError('Status antrian tidak valid', 400);
    }

    await conn.beginTransaction();

    const [qRows] = await conn.query<RowDataPacket[]>('SELECT booking_id FROM queues WHERE id = ? FOR UPDATE', [id]);
    if (qRows.length === 0) {
      await conn.rollback();
      throw new AppError('Antrian tidak ditemukan', 404);
    }

    await conn.query('UPDATE queues SET status = ? WHERE id = ?', [status, id]);

    // Sync booking status
    let bookingStatus = 'in_queue';
    if (status === 'in_progress') bookingStatus = 'in_service';
    else if (status === 'completed') bookingStatus = 'completed';
    else if (status === 'skipped') bookingStatus = 'cancelled';

    await conn.query('UPDATE bookings SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', [
      bookingStatus,
      qRows[0].booking_id,
    ]);

    await conn.commit();

    return sendSuccess(res, { id, status, bookingStatus }, 'Status antrian berhasil diperbarui');
  } catch (error) {
    await conn.rollback();
    next(error);
  } finally {
    conn.release();
  }
});

/**
 * @openapi
 * /api/queues/{id}:
 *   delete:
 *     tags:
 *       - Queues
 *     summary: Delete a queue item and cancel related booking
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Queue deleted successfully
 *       404:
 *         description: Queue not found
 */
router.delete('/:id', async (req: Request, res: Response, next: NextFunction) => {
  const conn = await dbPool.getConnection();
  try {
    const { id } = req.params;
    await conn.beginTransaction();

    const [qRows] = await conn.query<RowDataPacket[]>('SELECT booking_id FROM queues WHERE id = ? FOR UPDATE', [id]);
    if (qRows.length === 0) {
      await conn.rollback();
      throw new AppError('Antrian tidak ditemukan', 404);
    }

    await conn.query('DELETE FROM queues WHERE id = ?', [id]);
    await conn.query("UPDATE bookings SET status = 'cancelled' WHERE id = ?", [qRows[0].booking_id]);

    await conn.commit();
    return sendSuccess(res, { id }, 'Antrian berhasil dihapus');
  } catch (error) {
    await conn.rollback();
    next(error);
  } finally {
    conn.release();
  }
});

/**
 * @openapi
 * /api/queues/walk-in:
 *   post:
 *     tags:
 *       - Queues
 *     summary: Register instant walk-in customer into active queue
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               customerName:
 *                 type: string
 *                 example: Budi Santoso
 *               customerPhone:
 *                 type: string
 *                 example: 081298765432
 *               barberId:
 *                 type: string
 *               serviceIds:
 *                 type: array
 *                 items:
 *                   type: string
 *     responses:
 *       201:
 *         description: Walk-in customer registered to queue
 */
router.post('/walk-in', async (req: Request, res: Response, next: NextFunction) => {
  const conn = await dbPool.getConnection();
  try {
    const { customerName = 'Pelanggan Walk-in', customerPhone, barberId, serviceIds = [] } = req.body;

    await conn.beginTransaction();

    // Pick or create customer
    let customerId = crypto.randomUUID();
    const [existingCust] = await conn.query<RowDataPacket[]>(
      'SELECT id FROM customers WHERE full_name = ? LIMIT 1 FOR UPDATE',
      [customerName]
    );
    if (existingCust.length > 0) {
      customerId = existingCust[0].id;
    } else {
      const [uRows] = await conn.query<RowDataPacket[]>('SELECT id FROM users LIMIT 1');
      const userId = uRows[0]?.id || crypto.randomUUID();
      await conn.query(
        'INSERT INTO customers (id, user_id, full_name, phone_number) VALUES (?, ?, ?, ?)',
        [customerId, userId, customerName, customerPhone || null]
      );
    }

    // Pick default barber if not specified
    let bId = barberId;
    if (!bId || bId === 'all') {
      const [barberRows] = await conn.query<RowDataPacket[]>('SELECT id FROM barbers WHERE is_active = 1 LIMIT 1');
      bId = barberRows[0]?.id;
    }

    // Calculate total price from services
    let totalPrice = 0;
    if (Array.isArray(serviceIds) && serviceIds.length > 0) {
      const [srvRows] = await conn.query<RowDataPacket[]>(
        'SELECT SUM(price) as total FROM services WHERE id IN (?)',
        [serviceIds]
      );
      totalPrice = Number(srvRows[0]?.total || 50000);
    } else {
      totalPrice = 50000;
    }

    const bookingId = crypto.randomUUID();
    const bookingCode = `TRIM-W-${Date.now().toString(36).toUpperCase()}`;
    const now = new Date();
    const todayStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
    const timeStr = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}:00`;
    const endMinutes = now.getHours() * 60 + now.getMinutes() + 30;
    const endH = Math.floor(endMinutes / 60) % 24;
    const endM = endMinutes % 60;
    const endTimeStr = `${String(endH).padStart(2, '0')}:${String(endM).padStart(2, '0')}:00`;

    await conn.query(
      `INSERT INTO bookings (id, booking_code, customer_id, barber_id, booking_date, start_time, end_time, status, total_price)
       VALUES (?, ?, ?, ?, ?, ?, ?, 'in_queue', ?)`,
      [bookingId, bookingCode, customerId, bId, todayStr, timeStr, endTimeStr, totalPrice]
    );

    // Link booking services
    if (Array.isArray(serviceIds) && serviceIds.length > 0) {
      for (const sId of serviceIds) {
        await conn.query(
          'INSERT IGNORE INTO booking_services (booking_id, service_id) VALUES (?, ?)',
          [bookingId, sId]
        );
      }
    }

    // Generate queue number
    const [todayCount] = await conn.query<RowDataPacket[]>(
      'SELECT COUNT(*) as cnt FROM queues WHERE DATE(joined_at) = CURDATE() FOR UPDATE'
    );
    const nextSeq = String(Number(todayCount[0]?.cnt || 0) + 1).padStart(3, '0');
    const queueNumber = `A-${nextSeq}`;

    const queueId = crypto.randomUUID();
    await conn.query(
      `INSERT INTO queues (id, booking_id, queue_number, estimated_wait_time_mins, status)
       VALUES (?, ?, ?, 15, 'waiting')`,
      [queueId, bookingId, queueNumber]
    );

    await conn.commit();

    return sendSuccess(
      res,
      { queueId, queueNumber, bookingId, customerName, status: 'waiting' },
      'Antrean walk-in berhasil didaftarkan',
      201
    );
  } catch (error) {
    await conn.rollback();
    next(error);
  } finally {
    conn.release();
  }
});

export default router;
