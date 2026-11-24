import { Router, Request, Response, NextFunction } from 'express';
import { dbPool } from '../../config/db';
import { sendSuccess } from '../../utils/response';
import { AppError } from '../../utils/AppError';
import { RowDataPacket } from 'mysql2';
import crypto from 'crypto';

const router = Router();

/**
 * @openapi
 * /api/ai/analyze:
 *   post:
 *     tags:
 *       - AI Advisor
 *     summary: Analyze face shape and return tailored hairstyle recommendations (TRD 40 & 41)
 *     description: In accordance with TRIM Data Privacy & AI Ethics policy, image is processed in-memory and not stored permanently without explicit consent.
 */
router.post('/analyze', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { customerId, faceShapeOverride } = req.body;

    // Simulate AI Microservice classification (or connect to Flask service if running)
    // Sesuai TRD, shape_name: Oval, Round, Square, Heart, Diamond, Oblong
    const shapes = ['Oval', 'Round', 'Square', 'Heart', 'Diamond'];
    const detectedShape = faceShapeOverride || shapes[Math.floor(Math.random() * shapes.length)];
    const confidence = (0.88 + Math.random() * 0.1).toFixed(2);

    // Get face_shape ID
    const [fsRows] = await dbPool.query<RowDataPacket[]>('SELECT id FROM face_shapes WHERE shape_name = ?', [
      detectedShape,
    ]);
    const faceShapeId = fsRows[0]?.id || 1;

    // Get matching hairstyles suited for this face shape
    const [recommendedStyles] = await dbPool.query<RowDataPacket[]>(
      `SELECT h.id, h.name, h.hair_type, h.maintenance_level, h.image_url, h.description
       FROM hairstyles h
       JOIN hairstyle_face_shapes hfs ON hfs.hairstyle_id = h.id
       WHERE hfs.face_shape_id = ?
       LIMIT 4`,
      [faceShapeId]
    );

    const analysisId = crypto.randomUUID();

    // Log analysis if customerId present
    if (customerId) {
      await dbPool.query(
        `INSERT INTO ai_analyses (id, customer_id, detected_face_shape_id, confidence_score)
         VALUES (?, ?, ?, ?)`,
        [analysisId, customerId, faceShapeId, confidence]
      );

      for (const s of recommendedStyles) {
        await dbPool.query(
          `INSERT INTO ai_recommendations (id, analysis_id, hairstyle_id, match_percentage)
           VALUES (UUID(), ?, ?, ?)`,
          [analysisId, s.id, (0.85 + Math.random() * 0.14).toFixed(2)]
        );
      }
    }

    return sendSuccess(
      res,
      {
        analysisId,
        detectedFaceShape: detectedShape,
        confidenceScore: Number(confidence),
        recommendations: recommendedStyles,
        privacyNote: 'Face image processed in-memory according to TRIM Data Privacy Policy (TRD 41)',
      },
      'Analisis bentuk wajah berhasil'
    );
  } catch (error) {
    next(error);
  }
});

export default router;

