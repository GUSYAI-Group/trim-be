import { Router, Request, Response, NextFunction } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { z } from 'zod';
import { dbPool } from '../../config/db';
import { env } from '../../config/env';
import { sendSuccess } from '../../utils/response';
import { AppError } from '../../utils/AppError';
import { authenticate } from '../../middlewares/auth';
import { RowDataPacket } from 'mysql2';

const router = Router();

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

/**
 * @openapi
 * /api/auth/login:
 *   post:
 *     tags:
 *       - Authentication
 *     summary: User login
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *             properties:
 *               email:
 *                 type: string
 *                 example: owner@trim.id
 *               password:
 *                 type: string
 *                 example: password123
 *     responses:
 *       200:
 *         description: Login successful
 *       401:
 *         description: Invalid credentials
 */
router.post('/login', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const parse = loginSchema.safeParse(req.body);
    if (!parse.success) {
      throw new AppError('Invalid email or password format', 400, parse.error.format());
    }

    const { email, password } = parse.data;

    const [rows] = await dbPool.query<RowDataPacket[]>(
      `SELECT u.id, u.email, u.password_hash, u.role,
              c.full_name as customer_name, b.full_name as barber_name
       FROM users u
       LEFT JOIN customers c ON c.user_id = u.id
       LEFT JOIN barbers b ON b.user_id = u.id
       WHERE u.email = ? LIMIT 1`,
      [email]
    );

    if (rows.length === 0) {
      throw new AppError('Invalid email or password', 401);
    }

    const user = rows[0];
    const passwordMatch = await bcrypt.compare(password, user.password_hash);
    if (!passwordMatch) {
      throw new AppError('Invalid email or password', 401);
    }

    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role },
      env.jwt.secret,
      { expiresIn: env.jwt.expiresIn as any }
    );

    const name = user.customer_name || user.barber_name || (user.email.split('@')[0]);
    const initials = name
      .split(' ')
      .map((part: string) => part[0])
      .join('')
      .slice(0, 2)
      .toUpperCase();

    return sendSuccess(res, {
      token,
      user: {
        id: user.id,
        email: user.email,
        name,
        initials,
        role: user.role,
      },
    }, 'Login successful');
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/auth/me:
 *   get:
 *     tags:
 *       - Authentication
 *     summary: Get current authenticated user profile
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Current user data
 *       401:
 *         description: Unauthorized
 */
router.get('/me', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const [rows] = await dbPool.query<RowDataPacket[]>(
      `SELECT u.id, u.email, u.role,
              c.full_name as customer_name, c.phone_number as customer_phone,
              b.full_name as barber_name, b.phone_number as barber_phone
       FROM users u
       LEFT JOIN customers c ON c.user_id = u.id
       LEFT JOIN barbers b ON b.user_id = u.id
       WHERE u.id = ? LIMIT 1`,
      [req.user!.id]
    );

    if (rows.length === 0) {
      throw new AppError('User not found', 404);
    }

    const user = rows[0];
    const name = user.customer_name || user.barber_name || user.email.split('@')[0];
    const initials = name
      .split(' ')
      .map((part: string) => part[0])
      .join('')
      .slice(0, 2)
      .toUpperCase();

    return sendSuccess(res, {
      id: user.id,
      email: user.email,
      name,
      initials,
      role: user.role,
      phone: user.customer_phone || user.barber_phone || null,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/auth/profile:
 *   put:
 *     tags:
 *       - Authentication
 *     summary: Update current authenticated user profile (name, phone)
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *                 example: Aditya Pratama
 *               phone:
 *                 type: string
 *                 example: 081234567890
 *     responses:
 *       200:
 *         description: Profile updated successfully
 */
router.put('/profile', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { name, phone } = req.body;
    const userId = req.user!.id;

    if (name || phone) {
      await dbPool.query('UPDATE barbers SET full_name = COALESCE(?, full_name), phone_number = COALESCE(?, phone_number) WHERE user_id = ?', [name || null, phone || null, userId]);
      await dbPool.query('UPDATE customers SET full_name = COALESCE(?, full_name), phone_number = COALESCE(?, phone_number) WHERE user_id = ?', [name || null, phone || null, userId]);
    }

    return sendSuccess(res, { id: userId, name, phone }, 'Profil berhasil diperbarui');
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/auth/password:
 *   put:
 *     tags:
 *       - Authentication
 *     summary: Change password for current authenticated user
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - currentPassword
 *               - newPassword
 *             properties:
 *               currentPassword:
 *                 type: string
 *                 example: password123
 *               newPassword:
 *                 type: string
 *                 example: newPassword456
 *     responses:
 *       200:
 *         description: Password updated successfully
 *       400:
 *         description: Invalid current password
 */
router.put('/password', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { currentPassword, newPassword } = req.body;
    if (!currentPassword || !newPassword) {
      throw new AppError('Kata sandi saat ini dan kata sandi baru wajib diisi', 400);
    }

    const userId = req.user!.id;
    const [rows] = await dbPool.query<RowDataPacket[]>('SELECT password_hash FROM users WHERE id = ?', [userId]);
    if (rows.length === 0) throw new AppError('Pengguna tidak ditemukan', 404);

    const match = await bcrypt.compare(currentPassword, rows[0].password_hash);
    if (!match) throw new AppError('Kata sandi saat ini tidak sesuai', 400);

    const newHash = await bcrypt.hash(newPassword, 10);
    await dbPool.query('UPDATE users SET password_hash = ? WHERE id = ?', [newHash, userId]);

    return sendSuccess(res, null, 'Kata sandi berhasil diubah');
  } catch (error) {
    next(error);
  }
});

export default router;

