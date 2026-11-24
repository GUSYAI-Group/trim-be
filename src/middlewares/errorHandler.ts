import { NextFunction, Request, Response } from 'express';
import { AppError } from '../utils/AppError';
import { sendError } from '../utils/response';
import { env } from '../config/env';

export function notFoundHandler(req: Request, res: Response): Response {
  return sendError(res, `Route ${req.method} ${req.originalUrl} not found`, 404);
}

export function errorHandler(
  err: Error,
  _req: Request,
  res: Response,
  _next: NextFunction
): Response {
  if (err instanceof AppError) {
    return sendError(res, err.message, err.statusCode, err.errors);
  }

  if (env.nodeEnv !== 'production') {
    console.error('[Unhandled Error]', err);
  }

  return sendError(
    res,
    env.nodeEnv === 'production' ? 'Internal Server Error' : err.message || 'Internal Server Error',
    500
  );
}

