import { Router, Request, Response, NextFunction } from 'express';
import bcrypt from 'bcryptjs';
import { dbPool } from '../../config/db';
import { sendSuccess } from '../../utils/response';
import { AppError } from '../../utils/AppError';
import { RowDataPacket, ResultSetHeader } from 'mysql2';
import crypto from 'crypto';
import { authenticate, authorize } from '../../middlewares/auth';

const router = Router();

// Guard accounts management to owner role
router.use(authenticate, authorize('owner'));

/**
 * @openapi
 * /api/accounts:
 *   get:
 *     tags:
 *       - Accounts
 *     summary: Get all system user accounts (Admin/Owner)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: search
 *         schema:
 *           type: string
 *         description: Search by email or name
 *       - in: query
 *         name: role
 *         schema:
 *           type: string
 *           enum: [all, owner, admin, barber, customer]
 *     responses:
 *       200:
 *         description: List of user accounts
 */
router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { search, role } = req.query;

    let query = `
      SELECT 
        u.id,
        u.email,
        u.role,
        u.created_at,
        u.updated_at,
        COALESCE(c.full_name, b.full_name, SUBSTRING_INDEX(u.email, '@', 1)) as display_name
      FROM users u
      LEFT JOIN customers c ON c.user_id = u.id
      LEFT JOIN barbers b ON b.user_id = u.id
      WHERE 1=1
    `;
    const params: any[] = [];

    if (role && typeof role === 'string' && role !== 'all') {
      query += ` AND u.role = ?`;
      params.push(role);
    }

    if (search && typeof search === 'string' && search.trim() !== '') {
      query += ` AND (u.email LIKE ? OR c.full_name LIKE ? OR b.full_name LIKE ?)`;
      const term = `%${search.trim()}%`;
      params.push(term, term, term);
    }

    query += ` ORDER BY u.created_at DESC`;

    const [rows] = await dbPool.query<RowDataPacket[]>(query, params);

    const data = rows.map((u, index) => {
      const name = u.display_name || u.email;
      const initials = name
        .split(' ')
        .map((p: string) => p[0])
        .join('')
        .slice(0, 2)
        .toUpperCase();

      return {
        id: index + 1,
        slug: `user-${u.id.slice(0, 8)}`,
        uuid: u.id,
        email: u.email,
        displayName: name,
        initials,
        role: u.role,
        createdAt: u.created_at,
        updatedAt: u.updated_at,
        isOwner: u.role === 'owner',
      };
    });

    return sendSuccess(res, data);
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/accounts:
 *   post:
 *     tags:
 *       - Accounts
 *     summary: Create new system account (Owner/Admin)
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *             properties:
 *               email:
 *                 type: string
 *                 example: barber1@trim.id
 *               password:
 *                 type: string
 *                 example: password123
 *               role:
 *                 type: string
 *                 enum: [owner, admin, barber, customer]
 *                 example: barber
 *               displayName:
 *                 type: string
 *                 example: Ahmad Barber
 *               phone:
 *                 type: string
 *                 example: 08123456789
 *     responses:
 *       201:
 *         description: Account created successfully
 *       400:
 *         description: Email already registered or invalid input
 */
router.post('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { email, password = 'password123', role = 'barber', displayName, phone } = req.body;
    if (!email) throw new AppError('Email wajib diisi', 400);

    const [existing] = await dbPool.query<RowDataPacket[]>('SELECT id FROM users WHERE email = ?', [email]);
    if (existing.length > 0) throw new AppError('Email sudah terdaftar', 400);

    const userId = crypto.randomUUID();
    const hash = await bcrypt.hash(password, 10);

    await dbPool.query(
      `INSERT INTO users (id, email, password_hash, role) VALUES (?, ?, ?, ?)`,
      [userId, email, hash, role]
    );

    if (role === 'barber') {
      const barberId = crypto.randomUUID();
      await dbPool.query(
        `INSERT INTO barbers (id, user_id, full_name, phone_number, specialty, is_active, average_rating)
         VALUES (?, ?, ?, ?, 'General Cut', 1, 5.0)`,
        [barberId, userId, displayName || email.split('@')[0], phone || null]
      );
    } else if (role === 'customer') {
      const customerId = crypto.randomUUID();
      await dbPool.query(
        `INSERT INTO customers (id, user_id, full_name, phone_number)
         VALUES (?, ?, ?, ?)`,
        [customerId, userId, displayName || email.split('@')[0], phone || null]
      );
    }

    return sendSuccess(res, { id: userId, email, role }, 'Akun berhasil dibuat', 201);
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/accounts/{id}:
 *   get:
 *     tags:
 *       - Accounts
 *     summary: Get user account details by ID or UUID
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Account details
 *       404:
 *         description: Account not found
 */
router.get('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const cleanId = id.replace(/^user-/i, '');
    const [rows] = await dbPool.query<RowDataPacket[]>(
      `SELECT u.id, u.email, u.role, u.created_at, u.updated_at,
              COALESCE(c.full_name, b.full_name, SUBSTRING_INDEX(u.email, '@', 1)) as display_name,
              COALESCE(c.phone_number, b.phone_number, '') as phone
       FROM users u
       LEFT JOIN customers c ON c.user_id = u.id
       LEFT JOIN barbers b ON b.user_id = u.id
       WHERE u.id = ? OR u.id LIKE ? OR u.email = ?
       LIMIT 1`,
      [id, `${cleanId}%`, id]
    );

    if (rows.length === 0) throw new AppError('Akun tidak ditemukan', 404);

    const u = rows[0];
    const name = u.display_name || u.email;
    const initials = name
      .split(' ')
      .map((p: string) => p[0])
      .join('')
      .slice(0, 2)
      .toUpperCase();

    return sendSuccess(res, {
      uuid: u.id,
      email: u.email,
      displayName: name,
      initials,
      role: u.role,
      phone: u.phone,
      createdAt: u.created_at,
      updatedAt: u.updated_at,
      isOwner: u.role === 'owner',
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/accounts/{id}:
 *   put:
 *     tags:
 *       - Accounts
 *     summary: Update user account credentials or details
 *     security:
 *       - bearerAuth: []
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
 *             properties:
 *               email:
 *                 type: string
 *               password:
 *                 type: string
 *               role:
 *                 type: string
 *                 enum: [owner, admin, barber, customer]
 *               displayName:
 *                 type: string
 *               phone:
 *                 type: string
 *     responses:
 *       200:
 *         description: Account updated successfully
 *       404:
 *         description: Account not found
 */
router.put('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const { email, password, role, displayName, phone } = req.body;
    const cleanId = id.replace(/^user-/i, '');

    const [rows] = await dbPool.query<RowDataPacket[]>('SELECT id, role FROM users WHERE id = ? OR id LIKE ? LIMIT 1', [id, `${cleanId}%`]);
    if (rows.length === 0) throw new AppError('Akun tidak ditemukan', 404);
    const actualId = rows[0].id;

    if (email) {
      await dbPool.query('UPDATE users SET email = ? WHERE id = ?', [email, actualId]);
    }
    if (role) {
      await dbPool.query('UPDATE users SET role = ? WHERE id = ?', [role, actualId]);
    }
    if (password && password.trim() !== '') {
      const hash = await bcrypt.hash(password, 10);
      await dbPool.query('UPDATE users SET password_hash = ? WHERE id = ?', [hash, actualId]);
    }

    if (displayName || phone) {
      // update barbers or customers if linked
      await dbPool.query('UPDATE barbers SET full_name = COALESCE(?, full_name), phone_number = COALESCE(?, phone_number) WHERE user_id = ?', [displayName || null, phone || null, actualId]);
      await dbPool.query('UPDATE customers SET full_name = COALESCE(?, full_name), phone_number = COALESCE(?, phone_number) WHERE user_id = ?', [displayName || null, phone || null, actualId]);
    }

    return sendSuccess(res, { id: actualId }, 'Akun berhasil diperbarui');
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/accounts/{id}:
 *   delete:
 *     tags:
 *       - Accounts
 *     summary: Delete user account
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Account deleted successfully
 *       404:
 *         description: Account not found
 */
router.delete('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const [result] = await dbPool.query<ResultSetHeader>('DELETE FROM users WHERE id = ?', [id]);
    if (result.affectedRows === 0) throw new AppError('Akun tidak ditemukan', 404);
    return sendSuccess(res, { id }, 'Akun berhasil dihapus');
  } catch (error) {
    next(error);
  }
});

export default router;

