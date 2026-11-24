import { Router, Request, Response, NextFunction } from 'express';
import { dbPool } from '../../config/db';
import { sendSuccess } from '../../utils/response';
import { RowDataPacket } from 'mysql2';

const router = Router();

/**
 * @openapi
 * /api/hairstyles:
 *   get:
 *     tags:
 *       - Hairstyles
 *     summary: Get hairstyle catalog formatted matching Frontend THairstyle
 *     parameters:
 *       - in: query
 *         name: search
 *         schema:
 *           type: string
 *       - in: query
 *         name: faceShape
 *         schema:
 *           type: string
 *       - in: query
 *         name: hairType
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: List of hairstyles matching THairstyle
 */
router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { search, faceShape, hairType } = req.query;

    let query = `
      SELECT 
        h.id, h.name, h.hair_type, h.maintenance_level, h.image_url, h.description, h.is_active,
        (SELECT GROUP_CONCAT(fs.shape_name SEPARATOR ',') 
         FROM hairstyle_face_shapes hfs 
         JOIN face_shapes fs ON fs.id = hfs.face_shape_id 
         WHERE hfs.hairstyle_id = h.id) as face_shapes
      FROM hairstyles h
      WHERE 1=1
    `;
    const params: any[] = [];

    if (search && typeof search === 'string' && search.trim() !== '') {
      query += ` AND h.name LIKE ?`;
      params.push(`%${search.trim()}%`);
    }

    if (hairType && typeof hairType === 'string' && !['Semua', 'all'].includes(hairType)) {
      query += ` AND h.hair_type LIKE ?`;
      params.push(`%${hairType}%`);
    }

    if (faceShape && typeof faceShape === 'string' && !['Semua', 'all'].includes(faceShape)) {
      query += ` AND EXISTS (
        SELECT 1 FROM hairstyle_face_shapes hfs 
        JOIN face_shapes fs ON fs.id = hfs.face_shape_id 
        WHERE hfs.hairstyle_id = h.id AND fs.shape_name = ?
      )`;
      params.push(faceShape);
    }

    query += ` ORDER BY h.name ASC`;

    const [rows] = await dbPool.query<RowDataPacket[]>(query, params);

    const data = rows.map((h) => {
      const slug = h.name.toLowerCase().replace(/\s+/g, '-');
      const imageName = `${slug}.jpg`;
      return {
        id: slug,
        uuid: h.id,
        name: h.name,
        faceShapes: h.face_shapes ? h.face_shapes.split(',') : ['Oval'],
        description: h.description || `Potongan rambut ${h.name} dengan gaya modern dan rapi.`,
        hairType: h.hair_type || 'Lurus',
        maintenanceLevel: Number(h.maintenance_level || 2),
        image: h.image_url || `/hairstyles/${imageName}.png`,
        imageName,
        isAiActive: Boolean(h.is_active),
      };
    });

    return sendSuccess(res, data, 'OK', 200, { totalCount: data.length });
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/hairstyles/{id}:
 *   get:
 *     tags:
 *       - Hairstyles
 *     summary: Get single hairstyle details by slug or UUID
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Hairstyle details
 *       404:
 *         description: Hairstyle not found
 */
router.get('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const [rows] = await dbPool.query<RowDataPacket[]>(
      `SELECT h.id, h.name, h.hair_type, h.maintenance_level, h.image_url, h.description, h.is_active,
              GROUP_CONCAT(fs.shape_name SEPARATOR ',') as face_shapes
       FROM hairstyles h
       LEFT JOIN hairstyle_face_shapes hfs ON hfs.hairstyle_id = h.id
       LEFT JOIN face_shapes fs ON fs.id = hfs.face_shape_id
       WHERE h.id = ? OR LOWER(REPLACE(h.name, " ", "-")) = LOWER(?) OR h.name LIKE ?
       GROUP BY h.id
       LIMIT 1`,
      [id, id, `%${id.replace(/-/g, ' ')}%`]
    );

    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Model rambut tidak ditemukan' });
    }

    const h = rows[0];
    const slug = h.name.toLowerCase().replace(/\s+/g, '-');
    const imageName = `${slug}.jpg`;

    return sendSuccess(res, {
      id: slug,
      uuid: h.id,
      name: h.name,
      faceShapes: h.face_shapes ? h.face_shapes.split(',') : ['Oval'],
      description: h.description || `Potongan rambut ${h.name} dengan gaya modern dan rapi.`,
      hairType: h.hair_type || 'Lurus',
      maintenanceLevel: Number(h.maintenance_level || 2),
      image: h.image_url || `/hairstyles/${imageName}.png`,
      imageName,
      isAiActive: Boolean(h.is_active),
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/hairstyles:
 *   post:
 *     tags:
 *       - Hairstyles
 *     summary: Add new hairstyle to catalog and map to face shapes
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
 *                 example: Buzz Cut
 *               hairType:
 *                 type: string
 *                 example: Lurus
 *               maintenanceLevel:
 *                 type: integer
 *                 example: 1
 *               description:
 *                 type: string
 *                 example: Potongan rambut sangat pendek dan praktis
 *               faceShapes:
 *                 type: array
 *                 items:
 *                   type: string
 *                 example: ["Oval", "Persegi"]
 *               isAiActive:
 *                 type: boolean
 *                 example: true
 *     responses:
 *       201:
 *         description: Hairstyle created successfully
 */
router.post('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { name, hairType = 'Lurus', maintenanceLevel = 2, description, faceShapes = ['Oval'], isAiActive = true } = req.body;
    if (!name) return res.status(400).json({ success: false, message: 'Nama model rambut wajib diisi' });

    const hairstyleId = crypto.randomUUID();
    const slug = name.toLowerCase().replace(/\s+/g, '-');
    const imageUrl = `/hairstyles/${slug}.jpg`;

    await dbPool.query(
      `INSERT INTO hairstyles (id, name, hair_type, maintenance_level, image_url, description, is_active)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [hairstyleId, name, hairType, maintenanceLevel, imageUrl, description || null, isAiActive ? 1 : 0]
    );

    // Map face shapes
    for (const shapeName of faceShapes) {
      const [fs] = await dbPool.query<RowDataPacket[]>('SELECT id FROM face_shapes WHERE shape_name = ?', [shapeName]);
      if (fs.length > 0) {
        await dbPool.query(
          'INSERT IGNORE INTO hairstyle_face_shapes (hairstyle_id, face_shape_id) VALUES (?, ?)',
          [hairstyleId, fs[0].id]
        );
      }
    }

    return sendSuccess(res, { id: slug, uuid: hairstyleId, name }, 'Model rambut berhasil ditambahkan', 201);
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/hairstyles/{id}:
 *   put:
 *     tags:
 *       - Hairstyles
 *     summary: Update hairstyle details in catalog
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
 *               name:
 *                 type: string
 *               hairType:
 *                 type: string
 *               maintenanceLevel:
 *                 type: integer
 *               description:
 *                 type: string
 *               isAiActive:
 *                 type: boolean
 *     responses:
 *       200:
 *         description: Hairstyle updated successfully
 */
router.put('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const { name, hairType, maintenanceLevel, description, isAiActive } = req.body;

    const [find] = await dbPool.query<RowDataPacket[]>(
      'SELECT id FROM hairstyles WHERE id = ? OR LOWER(REPLACE(name, " ", "-")) = LOWER(?) OR name LIKE ?',
      [id, id, `%${id.replace(/-/g, ' ')}%`]
    );
    if (find.length === 0) return res.status(404).json({ success: false, message: 'Model rambut tidak ditemukan' });
    const actualId = find[0].id;

    await dbPool.query(
      `UPDATE hairstyles
       SET name = COALESCE(?, name),
           hair_type = COALESCE(?, hair_type),
           maintenance_level = COALESCE(?, maintenance_level),
           description = COALESCE(?, description),
           is_active = COALESCE(?, is_active)
       WHERE id = ?`,
      [
        name,
        hairType,
        maintenanceLevel !== undefined ? Number(maintenanceLevel) : null,
        description,
        typeof isAiActive === 'boolean' ? (isAiActive ? 1 : 0) : null,
        actualId,
      ]
    );

    return sendSuccess(res, { id: actualId }, 'Model rambut berhasil diperbarui');
  } catch (error) {
    next(error);
  }
});

/**
 * @openapi
 * /api/hairstyles/{id}:
 *   delete:
 *     tags:
 *       - Hairstyles
 *     summary: Delete a hairstyle and its related face shape mapping
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Hairstyle deleted successfully
 */
router.delete('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const [find] = await dbPool.query<RowDataPacket[]>(
      'SELECT id, name FROM hairstyles WHERE id = ? OR LOWER(REPLACE(name, " ", "-")) = LOWER(?) OR name LIKE ?',
      [id, id, `%${id.replace(/-/g, ' ')}%`]
    );
    if (find.length === 0) return res.status(404).json({ success: false, message: 'Model rambut tidak ditemukan' });
    const actualId = find[0].id;

    await dbPool.query('DELETE FROM ai_recommendations WHERE hairstyle_id = ?', [actualId]);
    await dbPool.query('DELETE FROM hairstyle_face_shapes WHERE hairstyle_id = ?', [actualId]);
    await dbPool.query('DELETE FROM hairstyles WHERE id = ?', [actualId]);

    return sendSuccess(res, { id: actualId }, `Model rambut "${find[0].name}" berhasil dihapus`);
  } catch (error) {
    next(error);
  }
});

export default router;
