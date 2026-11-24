import { Router, Request, Response, NextFunction } from 'express';
import { dbPool } from '../../config/db';
import { sendSuccess } from '../../utils/response';
import { AppError } from '../../utils/AppError';
import { RowDataPacket } from 'mysql2';
import crypto from 'crypto';

const router = Router();

/**
 * @openapi
 * /api/payments:
 *   get:
 *     tags:
 *       - Payments
 *     summary: Get transactions / payments history matching Frontend TPayment
 *     parameters:
 *       - in: query
 *         name: search
 *         schema:
 *           type: string
 *         description: Search by QRIS ref, ID, or customer name
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum: [all, lunas, paid, pending, menunggu, failed, gagal, refunded, dikembalikan]
 *       - in: query
 *         name: startDate
 *         schema:
 *           type: string
 *       - in: query
 *         name: endDate
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: List of payment records matching TPayment
 */
router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { search, status, startDate, endDate } = req.query;

    let query = `
      SELECT 
        p.id as payment_id,
        p.qris_reference_id,
        p.amount,
        p.status as payment_status,
        p.paid_at,
        p.created_at,
        b.id as booking_id,
        b.booking_date,
        b.start_time,
        c.full_name as customer_name,
        br.full_name as barber_name,
        (SELECT GROUP_CONCAT(s.name SEPARATOR ', ') 
         FROM booking_services bs 
         JOIN services s ON s.id = bs.service_id 
         WHERE bs.booking_id = b.id) as services
      FROM payments p
      JOIN bookings b ON b.id = p.booking_id
      LEFT JOIN customers c ON c.id = b.customer_id
      LEFT JOIN barbers br ON br.id = b.barber_id
      WHERE 1=1
    `;
    const params: any[] = [];

    if (search && typeof search === 'string' && search.trim() !== '') {
      query += ` AND (p.id LIKE ? OR p.qris_reference_id LIKE ? OR c.full_name LIKE ?)`;
      const term = `%${search.trim()}%`;
      params.push(term, term, term);
    }

    if (status && typeof status === 'string' && status !== 'all') {
      const sMap: Record<string, string> = {
        lunas: 'paid',
        paid: 'paid',
        menunggu: 'pending',
        pending: 'pending',
        gagal: 'failed',
        failed: 'failed',
        dikembalikan: 'refunded',
        refunded: 'refunded',
      };
      const dbStatus = sMap[status.toLowerCase()] || status;
      query += ` AND p.status = ?`;
      params.push(dbStatus);
    }

    if (startDate && typeof startDate === 'string') {
      query += ` AND DATE(p.created_at) >= ?`;
      params.push(startDate);
    }
    if (endDate && typeof endDate === 'string') {
      query += ` AND DATE(p.created_at) <= ?`;
      params.push(endDate);
    }

    query += ` ORDER BY p.created_at DESC`;

    const [rows] = await dbPool.query<RowDataPacket[]>(query, params);

    // Fetch overall global summary independent of table search / status filters
    const [summaryRows] = await dbPool.query<RowDataPacket[]>(`
      SELECT 
        COUNT(CASE WHEN status = 'paid' THEN 1 END) as totalLunas,
        COUNT(CASE WHEN status = 'pending' THEN 1 END) as totalMenunggu,
        COUNT(CASE WHEN status = 'failed' THEN 1 END) as totalGagal,
        COUNT(CASE WHEN status = 'refunded' THEN 1 END) as totalRefunded,
        COALESCE(SUM(CASE WHEN status = 'paid' THEN amount ELSE 0 END), 0) as totalOmset
      FROM payments
    `);

    const globalSummary = summaryRows[0] || {
      totalLunas: 0,
      totalMenunggu: 0,
      totalGagal: 0,
      totalRefunded: 0,
      totalOmset: 0,
    };

    let totalOmset = 0;
    let paidCount = 0;
    let pendingCount = 0;

    const data = rows.map((r, idx) => {
      const amt = Number(r.amount || 0);

      let feStatus: 'lunas' | 'menunggu' | 'gagal' | 'dikembalikan' = 'menunggu';
      if (r.payment_status === 'paid') feStatus = 'lunas';
      else if (r.payment_status === 'failed') feStatus = 'gagal';
      else if (r.payment_status === 'refunded') feStatus = 'dikembalikan';

      if (r.payment_status === 'paid') {
        totalOmset += amt;
        paidCount++;
      } else if (r.payment_status === 'pending') {
        pendingCount++;
      }

      const hasPaid = Boolean(r.paid_at && r.payment_status === 'paid');
      const paidDateStr = hasPaid
        ? new Date(r.paid_at).toLocaleDateString('id-ID', {
            day: 'numeric',
            month: 'short',
            year: 'numeric',
          }) + ` • ${new Date(r.paid_at).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })}`
        : '';

      return {
        id: idx + 1,
        paymentId: r.payment_id,
        qrisRef: r.qris_reference_id || `QRIS-${r.payment_id.slice(0, 8).toUpperCase()}`,
        qrisId: `id: ${r.payment_id.slice(0, 8)}...`,
        bookingUuid: `${r.booking_id.slice(0, 8)}...`,
        rawBookingId: r.booking_id,
        customer: r.customer_name || 'Pelanggan Umum',
        barber: r.barber_name || 'Kapster Bebas',
        services: r.services || 'Layanan Barbershop',
        paidAt: paidDateStr,
        nominal: `Rp${amt.toLocaleString('id-ID')}`,
        rawNominal: amt,
        status: feStatus,
        hasPaidAt: hasPaid,
      };
    });

    return sendSuccess(res, data, 'OK', 200, {
      totalCount: rows.length,
      paidCount,
      pendingCount,
      totalOmset: `Rp${Number(globalSummary.totalOmset).toLocaleString('id-ID')}`,
      rawTotalOmset: Number(globalSummary.totalOmset),
      summary: {
        totalLunas: Number(globalSummary.totalLunas || 0),
        totalMenunggu: Number(globalSummary.totalMenunggu || 0),
        totalGagal: Number(globalSummary.totalGagal || 0),
        totalRefunded: Number(globalSummary.totalRefunded || 0),
        totalOmset: `Rp${Number(globalSummary.totalOmset || 0).toLocaleString('id-ID')}`,
        rawTotalOmset: Number(globalSummary.totalOmset || 0),
      },
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/payments/create-qris:
 *   post:
 *     tags:
 *       - Payments
 *     summary: Generate dynamic QRIS for a booking
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
 *         description: QRIS code generated successfully
 *       404:
 *         description: Booking not found
 */
router.post('/create-qris', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { bookingId } = req.body;
    if (!bookingId) throw new AppError('bookingId wajib diisi', 400);

    const [bRows] = await dbPool.query<RowDataPacket[]>('SELECT total_price FROM bookings WHERE id = ?', [bookingId]);
    if (bRows.length === 0) throw new AppError('Booking tidak ditemukan', 404);

    const amount = Number(bRows[0].total_price || 50000);
    const paymentId = crypto.randomUUID();
    const qrisRef = `PAKKASIR-QR-${Date.now().toString(36).toUpperCase()}`;
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000);

    await dbPool.query(
      `INSERT INTO payments (id, booking_id, qris_reference_id, amount, status, expires_at)
       VALUES (?, ?, ?, ?, 'pending', ?)`,
      [paymentId, bookingId, qrisRef, amount, expiresAt]
    );

    return sendSuccess(
      res,
      {
        paymentId,
        qrisReferenceId: qrisRef,
        amount,
        status: 'pending',
        expiresAt: new Date(Date.now() + 15 * 60 * 1000).toISOString(),
        qrString: `00020101021226600016ID.CO.PAKKASIR0118${qrisRef}5204581253033605802ID5916TRIM BARBERSHOP6007SURABAYA6304ABCD`,
      },
      'QRIS berhasil dibuat (berlaku 15 menit)',
      201
    );
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/payments/webhook:
 *   post:
 *     tags:
 *       - Payments
 *     summary: Payment gateway webhook simulation callback
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - qrisReferenceId
 *             properties:
 *               qrisReferenceId:
 *                 type: string
 *               status:
 *                 type: string
 *                 enum: [paid, failed]
 *     responses:
 *       200:
 *         description: Webhook processed
 *       404:
 *         description: Payment transaction not found
 */
router.post('/webhook', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { qrisReferenceId, status } = req.body;
    if (!qrisReferenceId) throw new AppError('qrisReferenceId wajib disertakan', 400);

    const newStatus = status === 'paid' ? 'paid' : 'failed';
    const paidAt = newStatus === 'paid' ? new Date() : null;

    const [pRows] = await dbPool.query<RowDataPacket[]>(
      'SELECT id, booking_id FROM payments WHERE qris_reference_id = ?',
      [qrisReferenceId]
    );
    if (pRows.length === 0) throw new AppError('Transaksi pembayaran tidak ditemukan', 404);

    await dbPool.query(
      'UPDATE payments SET status = ?, paid_at = ? WHERE qris_reference_id = ?',
      [newStatus, paidAt, qrisReferenceId]
    );

    if (newStatus === 'paid') {
      await dbPool.query("UPDATE bookings SET status = 'confirmed', updated_at = CURRENT_TIMESTAMP WHERE id = ?", [
        pRows[0].booking_id,
      ]);
    }

    return sendSuccess(res, { qrisReferenceId, status: newStatus }, 'Webhook pembayaran berhasil diproses');
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/payments/{id}/pay:
 *   patch:
 *     tags:
 *       - Payments
 *     summary: Cashier manually marks a pending payment as paid (Cash or Manual QRIS)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Payment ID or QRIS reference ID
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               paymentMethod:
 *                 type: string
 *                 enum: [cash, qris, transfer]
 *                 default: cash
 *     responses:
 *       200:
 *         description: Payment marked as paid successfully
 *       404:
 *         description: Payment not found
 */
router.patch('/:id/pay', async (req: Request, res: Response, next: NextFunction) => {
  const conn = await dbPool.getConnection();
  try {
    const { id } = req.params;
    const { paymentMethod = 'cash' } = req.body;

    await conn.beginTransaction();

    const [pRows] = await conn.query<RowDataPacket[]>(
      'SELECT id, booking_id, amount, status FROM payments WHERE id = ? OR qris_reference_id = ? OR id LIKE ? LIMIT 1',
      [id, id, `%${id}%`]
    );

    if (pRows.length === 0) {
      await conn.rollback();
      throw new AppError('Data pembayaran tidak ditemukan', 404);
    }

    const payment = pRows[0];
    const now = new Date();

    await conn.query(
      `UPDATE payments 
       SET status = 'paid', paid_at = ? 
       WHERE id = ?`,
      [now, payment.id]
    );

    // Update booking status to completed
    await conn.query(
      `UPDATE bookings 
       SET status = 'completed', updated_at = ? 
       WHERE id = ?`,
      [now, payment.booking_id]
    );

    // Sync queue status if linked
    await conn.query(
      `UPDATE queues 
       SET status = 'completed' 
       WHERE booking_id = ?`,
      [payment.booking_id]
    );

    await conn.commit();

    return sendSuccess(
      res,
      {
        id: payment.id,
        bookingId: payment.booking_id,
        status: 'paid',
        paymentMethod,
        paidAt: now.toISOString(),
      },
      `Pembayaran sebesar Rp${Number(payment.amount || 0).toLocaleString('id-ID')} berhasil dilunasi (${paymentMethod.toUpperCase()})`
    );
  } catch (error) {
    await conn.rollback();
    next(error);
  } finally {
    conn.release();
  }
});

export default router;
