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
 * /api/products:
 *   get:
 *     tags:
 *       - Products
 *     summary: Get all products formatted matching Frontend TProduct
 *     parameters:
 *       - in: query
 *         name: search
 *         schema:
 *           type: string
 *         description: Search by product name
 *       - in: query
 *         name: category
 *         schema:
 *           type: string
 *         description: Filter by category (e.g. Minyak Rambut, Hair Spray, Powder, etc.)
 *       - in: query
 *         name: stockStatus
 *         schema:
 *           type: string
 *           enum: [Semua, Aman, Menipis, Habis]
 *       - in: query
 *         name: activeStatus
 *         schema:
 *           type: string
 *           enum: [Semua, Aktif, Nonaktif]
 *     responses:
 *       200:
 *         description: List of products matching TProduct
 */
router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { search, category, stockStatus, activeStatus } = req.query;

    let query = `
      SELECT id, name, category, stock_quantity as stock, minimum_stock_alert as minStock,
             unit_price as price, is_active, created_at, updated_at
      FROM products
      WHERE 1=1
    `;
    const params: any[] = [];

    if (search && typeof search === 'string' && search.trim() !== '') {
      query += ` AND name LIKE ?`;
      params.push(`%${search.trim()}%`);
    }

    if (category && typeof category === 'string' && !['Semua', 'Semua kategori', 'all'].includes(category)) {
      query += ` AND category = ?`;
      params.push(category);
    }

    if (activeStatus && typeof activeStatus === 'string' && !['Semua', 'all'].includes(activeStatus)) {
      if (activeStatus.toLowerCase() === 'aktif') query += ` AND is_active = 1`;
      else if (activeStatus.toLowerCase() === 'nonaktif') query += ` AND is_active = 0`;
    }

    if (stockStatus && typeof stockStatus === 'string' && !['Semua', 'all'].includes(stockStatus)) {
      if (stockStatus === 'Habis') query += ` AND stock_quantity = 0`;
      else if (stockStatus === 'Menipis') query += ` AND stock_quantity > 0 AND stock_quantity <= minimum_stock_alert`;
      else if (stockStatus === 'Aman') query += ` AND stock_quantity > minimum_stock_alert`;
    }

    query += ` ORDER BY name ASC`;

    const [rows] = await dbPool.query<RowDataPacket[]>(query, params);

    const formatDateSafe = (d: any) => {
      if (!d) return '-';
      const parsed = new Date(d);
      return isNaN(parsed.getTime())
        ? '-'
        : parsed.toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' });
    };

    const data = rows.map((p, idx) => {
      let calcStatus: 'Aman' | 'Menipis' | 'Habis' = 'Aman';
      if (p.stock === 0) calcStatus = 'Habis';
      else if (p.stock <= p.minStock) calcStatus = 'Menipis';

      const priceNum = Number(p.price || 0);

      return {
        id: p.id,
        rawId: p.name.toLowerCase().replace(/\s+/g, '-'),
        uuid: `PRD-${p.id.slice(0, 8).toUpperCase()}`,
        name: p.name,
        category: p.category,
        price: priceNum,
        priceFormatted: `Rp${priceNum.toLocaleString('id-ID')}`,
        stock: Number(p.stock),
        minStock: Number(p.minStock),
        stockStatus: calcStatus,
        isActive: Boolean(p.is_active),
        description: `${p.name} berkualitas tinggi untuk penataan dan perawatan rambut optimal.`,
        createdAt: formatDateSafe(p.created_at),
        updatedAt: formatDateSafe(p.updated_at || p.created_at),
      };
    });

    const [counts] = await dbPool.query<RowDataPacket[]>(`
      SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN is_active = 1 THEN 1 ELSE 0 END) as active,
        SUM(CASE WHEN stock_quantity = 0 THEN 1 ELSE 0 END) as habis,
        SUM(CASE WHEN stock_quantity > 0 AND stock_quantity <= minimum_stock_alert THEN 1 ELSE 0 END) as menipis,
        SUM(CASE WHEN stock_quantity > minimum_stock_alert THEN 1 ELSE 0 END) as aman
      FROM products
    `);

    return sendSuccess(res, data, 'OK', 200, {
      totalCount: Number(counts[0]?.total || data.length),
      activeCount: Number(counts[0]?.active || 0),
      amanCount: Number(counts[0]?.aman || 0),
      menipisCount: Number(counts[0]?.menipis || 0),
      habisCount: Number(counts[0]?.habis || 0),
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/products:
 *   post:
 *     tags:
 *       - Products
 *     summary: Add new product
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
 *               category:
 *                 type: string
 *                 default: Styling
 *               price:
 *                 type: number
 *                 default: 0
 *               stock:
 *                 type: integer
 *                 default: 0
 *               minStock:
 *                 type: integer
 *                 default: 5
 *               isActive:
 *                 type: boolean
 *                 default: true
 *     responses:
 *       201:
 *         description: Product added successfully
 *       400:
 *         description: Validation error
 */
router.post('/', authenticate, authorize('owner', 'admin'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { name, category = 'Styling', price = 0, stock = 0, minStock = 5, isActive = true } = req.body;
    if (!name) throw new AppError('Nama produk wajib diisi', 400);

    const productId = crypto.randomUUID();
    await dbPool.query(
      `INSERT INTO products (id, name, category, unit_price, stock_quantity, minimum_stock_alert, is_active)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [productId, name, category, price, stock, minStock, isActive ? 1 : 0]
    );

    return sendSuccess(res, { id: productId, name }, 'Produk berhasil ditambahkan', 201);
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/products/{id}:
 *   get:
 *     tags:
 *       - Products
 *     summary: Get single product detail
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Product details
 *       404:
 *         description: Product not found
 */
router.get('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const [rows] = await dbPool.query<RowDataPacket[]>(
      `SELECT id, name, category, stock_quantity as stock, minimum_stock_alert as minStock,
              unit_price as price, is_active, created_at, updated_at
       FROM products
       WHERE id = ? OR id LIKE ? OR LOWER(REPLACE(name, " ", "-")) = LOWER(?)
       LIMIT 1`,
      [id, `%${id.replace(/^PRD-/i, '')}%`, id]
    );

    if (rows.length === 0) throw new AppError('Produk tidak ditemukan', 404);

    const p = rows[0];
    let calcStatus: 'Aman' | 'Menipis' | 'Habis' = 'Aman';
    if (p.stock === 0) calcStatus = 'Habis';
    else if (p.stock <= p.minStock) calcStatus = 'Menipis';

    const priceNum = Number(p.price || 0);

    return sendSuccess(res, {
      id: p.id,
      rawId: p.name.toLowerCase().replace(/\s+/g, '-'),
      uuid: `PRD-${p.id.slice(0, 8).toUpperCase()}`,
      name: p.name,
      category: p.category,
      price: priceNum,
      priceFormatted: `Rp${priceNum.toLocaleString('id-ID')}`,
      stock: Number(p.stock),
      minStock: Number(p.minStock),
      stockStatus: calcStatus,
      isActive: Boolean(p.is_active),
      description: `${p.name} berkualitas tinggi untuk penataan dan perawatan rambut optimal.`,
      createdAt: new Date(p.created_at).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' }),
      updatedAt: new Date(p.updated_at || p.created_at).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' }),
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/products/{id}:
 *   put:
 *     tags:
 *       - Products
 *     summary: Update product information
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
 *               price:
 *                 type: number
 *               stock:
 *                 type: integer
 *               minStock:
 *                 type: integer
 *               isActive:
 *                 type: boolean
 *     responses:
 *       200:
 *         description: Product updated successfully
 *       404:
 *         description: Product not found
 */
router.put('/:id', authenticate, authorize('owner', 'admin'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const { name, category, price, stock, minStock, isActive } = req.body;

    const [findRows] = await dbPool.query<RowDataPacket[]>(
      'SELECT id FROM products WHERE id = ? OR id LIKE ? OR LOWER(REPLACE(name, " ", "-")) = LOWER(?)',
      [id, `%${id.replace(/^PRD-/i, '')}%`, id]
    );
    if (findRows.length === 0) throw new AppError('Produk tidak ditemukan', 404);
    const actualId = findRows[0].id;

    await dbPool.query(
      `UPDATE products
       SET name = COALESCE(?, name),
           category = COALESCE(?, category),
           unit_price = COALESCE(?, unit_price),
           stock_quantity = COALESCE(?, stock_quantity),
           minimum_stock_alert = COALESCE(?, minimum_stock_alert),
           is_active = COALESCE(?, is_active)
       WHERE id = ?`,
      [
        name,
        category,
        price !== undefined ? Number(price) : null,
        stock !== undefined ? Number(stock) : null,
        minStock !== undefined ? Number(minStock) : null,
        typeof isActive === 'boolean' ? (isActive ? 1 : 0) : null,
        actualId,
      ]
    );

    return sendSuccess(res, { id: actualId }, 'Produk berhasil diperbarui');
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/products/{id}/status:
 *   patch:
 *     tags:
 *       - Products
 *     summary: Toggle or update product active status
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
 *               isActive:
 *                 type: boolean
 *     responses:
 *       200:
 *         description: Product status updated successfully
 *       404:
 *         description: Product not found
 */
router.patch('/:id/status', authenticate, authorize('owner', 'admin'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const { isActive } = req.body;

    const [findRows] = await dbPool.query<RowDataPacket[]>(
      'SELECT id, is_active FROM products WHERE id = ? OR id LIKE ? OR LOWER(REPLACE(name, " ", "-")) = LOWER(?)',
      [id, `%${id.replace(/^PRD-/i, '')}%`, id]
    );
    if (findRows.length === 0) throw new AppError('Produk tidak ditemukan', 404);
    const actualId = findRows[0].id;

    const nextState = typeof isActive === 'boolean' ? (isActive ? 1 : 0) : findRows[0].is_active === 1 ? 0 : 1;
    await dbPool.query('UPDATE products SET is_active = ? WHERE id = ?', [nextState, actualId]);

    return sendSuccess(res, { id: actualId, isActive: Boolean(nextState) }, 'Status produk berhasil diperbarui');
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/products/{id}:
 *   delete:
 *     tags:
 *       - Products
 *     summary: Delete a product (or mark inactive if related history exists)
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
 *         description: Product deleted or deactivated successfully
 *       404:
 *         description: Product not found
 */
router.delete('/:id', authenticate, authorize('owner', 'admin'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const [findRows] = await dbPool.query<RowDataPacket[]>(
      'SELECT id, name FROM products WHERE id = ? OR id LIKE ? OR LOWER(REPLACE(name, " ", "-")) = LOWER(?)',
      [id, `%${id.replace(/^PRD-/i, '')}%`, id]
    );
    if (findRows.length === 0) throw new AppError('Produk tidak ditemukan', 404);
    const actualId = findRows[0].id;

    try {
      await dbPool.query('DELETE FROM products WHERE id = ?', [actualId]);
      return sendSuccess(res, { id: actualId }, `Produk "${findRows[0].name}" berhasil dihapus`);
    } catch (_err) {
      await dbPool.query('UPDATE products SET is_active = 0 WHERE id = ?', [actualId]);
      return sendSuccess(res, { id: actualId, is_active: 0 }, `Produk memiliki riwayat transaksi, status diubah menjadi Nonaktif`);
    }
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/products/{id}/adjust-stock:
 *   post:
 *     tags:
 *       - Products
 *     summary: Adjust product stock quantity with inventory transaction logging (ACID)
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
 *             required:
 *               - type
 *               - quantity
 *             properties:
 *               type:
 *                 type: string
 *                 enum: [stock_in, stock_out, adjustment]
 *               quantity:
 *                 type: integer
 *               notes:
 *                 type: string
 *     responses:
 *       200:
 *         description: Stock adjusted successfully
 *       400:
 *         description: Invalid stock operation or insufficient stock
 *       404:
 *         description: Product not found
 */
router.post('/:id/adjust-stock', authenticate, authorize('owner', 'admin'), async (req: Request, res: Response, next: NextFunction) => {
  const conn = await dbPool.getConnection();
  try {
    const { id } = req.params;
    const { type, quantity, notes } = req.body;

    if (!type || !['stock_in', 'stock_out', 'adjustment'].includes(type)) {
      throw new AppError('Tipe penyesuaian harus stock_in, stock_out, atau adjustment', 400);
    }
    const qty = Number(quantity);
    if (isNaN(qty) || qty < 0) {
      throw new AppError('Jumlah quantity harus berupa angka valid >= 0', 400);
    }

    await conn.beginTransaction();

    const [findRows] = await conn.query<RowDataPacket[]>(
      'SELECT id, name, stock_quantity FROM products WHERE id = ? OR id LIKE ? OR LOWER(REPLACE(name, " ", "-")) = LOWER(?) FOR UPDATE',
      [id, `%${id.replace(/^PRD-/i, '')}%`, id]
    );
    if (findRows.length === 0) {
      await conn.rollback();
      throw new AppError('Produk tidak ditemukan', 404);
    }

    const product = findRows[0];
    const currentStock = Number(product.stock_quantity || 0);
    let newStock = currentStock;
    let delta = qty;

    if (type === 'stock_in') {
      newStock = currentStock + qty;
    } else if (type === 'stock_out') {
      if (currentStock < qty) {
        await conn.rollback();
        throw new AppError(`Stok tidak mencukupi (stok saat ini: ${currentStock}, diminta keluar: ${qty})`, 400);
      }
      newStock = currentStock - qty;
    } else if (type === 'adjustment') {
      newStock = qty;
      delta = qty - currentStock;
    }

    await conn.query('UPDATE products SET stock_quantity = ? WHERE id = ?', [newStock, product.id]);

    const txId = crypto.randomUUID();
    await conn.query(
      `INSERT INTO inventory_transactions (id, product_id, transaction_type, quantity, notes, created_at)
       VALUES (?, ?, ?, ?, ?, NOW())`,
      [txId, product.id, type, Math.abs(delta), notes || `Penyesuaian stok (${type})`]
    );

    await conn.commit();

    return sendSuccess(
      res,
      {
        id: product.id,
        name: product.name,
        previousStock: currentStock,
        newStock,
        type,
        quantity: qty,
      },
      `Stok produk "${product.name}" berhasil disesuaikan menjadi ${newStock}`
    );
  } catch (error) {
    await conn.rollback();
    next(error);
  } finally {
    conn.release();
  }
});

export default router;
