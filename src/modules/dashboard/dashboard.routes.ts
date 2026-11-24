import { Router, Request, Response, NextFunction } from 'express';
import { dbPool } from '../../config/db';
import { sendSuccess } from '../../utils/response';
import { RowDataPacket } from 'mysql2';

const router = Router();

/**
 * @openapi
 * /api/dashboard/stats:
 *   get:
 *     tags:
 *       - Dashboard
 *     summary: Get live dashboard KPIs, 7-day revenue chart, floor status, and leaderboard
 */
router.get('/stats', async (_req: Request, res: Response, next: NextFunction) => {
  try {
    // 1. Live Payments & Revenue
    const [revTodayRows] = await dbPool.query<RowDataPacket[]>(
      `SELECT COALESCE(SUM(amount), 0) as today_revenue, COUNT(*) as today_paid_count
       FROM payments 
       WHERE status = 'paid' AND (DATE(paid_at) = CURDATE() OR DATE(created_at) = CURDATE())`
    );

    const [totalRevRows] = await dbPool.query<RowDataPacket[]>(
      `SELECT COALESCE(SUM(amount), 0) as total_revenue, COUNT(*) as total_paid_count
       FROM payments 
       WHERE status = 'paid'`
    );

    // 2. Bookings Stats
    const [bookingStatsRows] = await dbPool.query<RowDataPacket[]>(
      `SELECT 
         COUNT(*) as today_appointments,
         COUNT(DISTINCT customer_id) as today_customers,
         COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_services
       FROM bookings 
       WHERE booking_date = CURDATE()`
    );

    // 3. Barbers Aggregate Stats
    let totalRevCount = 0;
    let avgRat = 0;
    let activeBarbersCount = 0;
    try {
      const [barberCountRows] = await dbPool.query<RowDataPacket[]>(
        'SELECT COUNT(*) as active_barbers_count FROM barbers WHERE is_active = 1'
      );
      activeBarbersCount = Number(barberCountRows[0]?.active_barbers_count || 0);

      const [revRows] = await dbPool.query<RowDataPacket[]>(
        'SELECT COUNT(*) as total_reviews, ROUND(AVG(rating_barber), 1) as avg_rating FROM reviews'
      );
      totalRevCount = Number(revRows[0]?.total_reviews || 0);
      avgRat = totalRevCount > 0 && revRows[0]?.avg_rating ? Number(revRows[0].avg_rating) : 0;
    } catch (_err) {
      // safe fallback
    }

    // 4. Queues Live Floor Stats
    const [queueStatsRows] = await dbPool.query<RowDataPacket[]>(
      `SELECT 
         COUNT(CASE WHEN status = 'waiting' THEN 1 END) as waiting_count,
         COUNT(CASE WHEN status = 'in_progress' THEN 1 END) as in_progress_count,
         COUNT(CASE WHEN status = 'completed' AND DATE(joined_at) = CURDATE() THEN 1 END) as completed_today_count
       FROM queues`
    );

    // 5. Late Bookings Today
    const [lateBookingsRows] = await dbPool.query<RowDataPacket[]>(
      `SELECT b.id, c.full_name as customer_name, b.start_time
       FROM bookings b
       LEFT JOIN customers c ON c.id = b.customer_id
       LEFT JOIN queues q ON q.booking_id = b.id
       WHERE b.booking_date = CURDATE() 
         AND b.status = 'confirmed'
         AND q.id IS NULL
         AND b.start_time < CURTIME()`
    );

    // 6. Weekly Revenue (Last 7 Days Chart)
    const days: { dateStr: string; label: string; dayIndex: number }[] = [];
    for (let i = 6; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      const dateStr = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
      const label = d.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' });
      days.push({ dateStr, label, dayIndex: i });
    }

    const [weeklyRevRows] = await dbPool.query<RowDataPacket[]>(
      `SELECT 
         DATE(COALESCE(paid_at, created_at)) as pay_date,
         COALESCE(SUM(amount), 0) as daily_revenue
       FROM payments
       WHERE status = 'paid' 
         AND DATE(COALESCE(paid_at, created_at)) >= DATE_SUB(CURDATE(), INTERVAL 6 DAY)
       GROUP BY DATE(COALESCE(paid_at, created_at))`
    );

    const revMap = new Map<string, number>();
    weeklyRevRows.forEach((r) => {
      const dateStr =
        r.pay_date instanceof Date
          ? `${r.pay_date.getFullYear()}-${String(r.pay_date.getMonth() + 1).padStart(2, '0')}-${String(r.pay_date.getDate()).padStart(2, '0')}`
          : String(r.pay_date).slice(0, 10);
      revMap.set(dateStr, Number(r.daily_revenue || 0));
    });

    let maxVal = 0;
    let totalWeeklyRevenue = 0;
    const rawBars = days.map((day) => {
      const val = revMap.get(day.dateStr) || 0;
      totalWeeklyRevenue += val;
      if (val > maxVal) maxVal = val;
      return {
        label: day.label,
        date: day.dateStr,
        rawVal: val,
        active: day.dayIndex === 0,
      };
    });

    const scaleBase = maxVal > 0 ? maxVal * 1.2 : 100000;
    const bars = rawBars.map((bar) => {
      const heightPct = maxVal > 0 ? Math.max(12, Math.round((bar.rawVal / scaleBase) * 100)) : 14;
      const formattedVal =
        bar.rawVal >= 1000000
          ? `${(bar.rawVal / 1000000).toLocaleString('id-ID', { maximumFractionDigits: 1 })} jt`
          : bar.rawVal >= 1000
          ? `${Math.round(bar.rawVal / 1000)} rb`
          : bar.rawVal > 0
          ? `${bar.rawVal}`
          : '0';

      return {
        ...bar,
        height: `${heightPct}%`,
        val: formattedVal,
      };
    });

    const [prevRevRows] = await dbPool.query<RowDataPacket[]>(
      `SELECT COALESCE(SUM(amount), 0) as prev_revenue
       FROM payments
       WHERE status = 'paid' 
         AND DATE(COALESCE(paid_at, created_at)) >= DATE_SUB(CURDATE(), INTERVAL 13 DAY)
         AND DATE(COALESCE(paid_at, created_at)) < DATE_SUB(CURDATE(), INTERVAL 6 DAY)`
    );
    const prevWeeklyRevenue = Number(prevRevRows[0]?.prev_revenue || 0);

    let growthPercent = '0% minggu lalu';
    if (prevWeeklyRevenue === 0 && totalWeeklyRevenue === 0) {
      growthPercent = '0% minggu lalu';
    } else if (prevWeeklyRevenue === 0 && totalWeeklyRevenue > 0) {
      growthPercent = '↑ 100% minggu lalu';
    } else if (prevWeeklyRevenue > 0) {
      const diffPct = ((totalWeeklyRevenue - prevWeeklyRevenue) / prevWeeklyRevenue) * 100;
      if (diffPct > 0) {
        growthPercent = `↑ ${diffPct.toFixed(1).replace('.', ',')}% minggu lalu`;
      } else if (diffPct < 0) {
        growthPercent = `↓ ${Math.abs(diffPct).toFixed(1).replace('.', ',')}% minggu lalu`;
      } else {
        growthPercent = '0% minggu lalu';
      }
    }

    // 7. Leaderboard & Popular Styles
    let topBarbers: any[] = [];
    try {
      const [tb] = await dbPool.query<RowDataPacket[]>('SELECT * FROM v_barber_leaderboard LIMIT 5');
      topBarbers = tb;
    } catch (_err) {
      try {
        const [tbFallback] = await dbPool.query<RowDataPacket[]>(
          `SELECT 
             b.id as barber_id,
             b.full_name as barber_name,
             b.specialty,
             b.average_rating,
             COUNT(DISTINCT bk.id) as total_completed_services,
             COALESCE(SUM(p.amount), 0) as total_revenue_generated
           FROM barbers b
           LEFT JOIN bookings bk ON bk.barber_id = b.id AND bk.status = 'completed'
           LEFT JOIN payments p ON p.booking_id = bk.id AND p.status = 'paid'
           WHERE b.is_active = 1
           GROUP BY b.id, b.full_name, b.specialty, b.average_rating
           ORDER BY total_completed_services DESC, b.average_rating DESC
           LIMIT 5`
        );
        topBarbers = tbFallback.map((tbRow) => {
          return {
            ...tbRow,
            average_rating: Number(tbRow.average_rating || 0),
          };
        });
      } catch (_fbErr) {
        topBarbers = [];
      }
    }

    let popularStyles: any[] = [];
    try {
      const [ps] = await dbPool.query<RowDataPacket[]>('SELECT * FROM v_popular_hairstyles LIMIT 5');
      popularStyles = ps;
    } catch (_err) {
      const [psFallback] = await dbPool.query<RowDataPacket[]>(
        `SELECT id as hairstyle_id, name as hairstyle_name FROM hairstyles LIMIT 5`
      );
      popularStyles = psFallback;
    }

    let stockAlerts: any[] = [];
    try {
      const [sa] = await dbPool.query<RowDataPacket[]>('SELECT * FROM v_inventory_stock_alerts LIMIT 5');
      stockAlerts = sa;
    } catch (_err) {
      const [saFallback] = await dbPool.query<RowDataPacket[]>(
        `SELECT id, name, stock_quantity as current_stock, minimum_stock_alert 
         FROM products 
         WHERE stock_quantity <= minimum_stock_alert AND is_active = 1 
         LIMIT 5`
      );
      stockAlerts = saFallback;
    }

    const todayRevenue = Number(revTodayRows[0]?.today_revenue || 0);
    const totalAllTimeRevenue = Number(totalRevRows[0]?.total_revenue || 0);

    const now = new Date();
    const currentDateFormatted =
      now.toLocaleDateString('id-ID', {
        weekday: 'long',
        day: 'numeric',
        month: 'long',
      }) + ` • ${now.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })} WIB`;

    const lateCount = lateBookingsRows.length;
    const lateNames = lateBookingsRows
      .map((b) => b.customer_name || 'Pelanggan')
      .slice(0, 3)
      .join(', ');

    return sendSuccess(res, {
      kpi: {
        today_revenue: todayRevenue > 0 ? todayRevenue : totalAllTimeRevenue,
        completed_services: Number(bookingStatsRows[0]?.completed_services || 0),
        today_appointments: Number(bookingStatsRows[0]?.today_appointments || 0),
        today_customers: Number(bookingStatsRows[0]?.today_customers || 0),
        currently_in_queue: Number(queueStatsRows[0]?.waiting_count || 0),
        average_rating: avgRat,
        total_reviews: totalRevCount,
        active_barbers_count: activeBarbersCount,
        total_all_time_revenue: totalAllTimeRevenue,
      },
      weeklyRevenue: {
        totalRevenue: totalWeeklyRevenue,
        formattedTotal: `Rp${totalWeeklyRevenue.toLocaleString('id-ID')}`,
        growthPercent,
        periodLabel: `${days[0]?.label}–${days[days.length - 1]?.label} ${now.getFullYear()} • PAYMENTS.status = paid`,
        bars,
      },
      floorStatus: {
        currentDateFormatted,
        waiting: Number(queueStatsRows[0]?.waiting_count || 0),
        inProgress: Number(queueStatsRows[0]?.in_progress_count || 0),
        completed: Number(queueStatsRows[0]?.completed_today_count || 0),
        lateCount,
        lateCustomerNames: lateNames,
      },
      topBarbers,
      popularStyles,
      stockAlerts,
    });
  } catch (error) {
    next(error);
  }
});

export default router;

