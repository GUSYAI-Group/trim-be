import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import swaggerUi from 'swagger-ui-express';
import { env } from './config/env';
import { swaggerSpec } from './config/swagger';
import healthRoutes from './modules/health/health.routes';
import authRoutes from './modules/auth/auth.routes';
import accountsRoutes from './modules/accounts/accounts.routes';
import barbersRoutes from './modules/barbers/barbers.routes';
import servicesRoutes from './modules/services/services.routes';
import productsRoutes from './modules/products/products.routes';
import hairstylesRoutes from './modules/hairstyles/hairstyles.routes';
import bookingsRoutes from './modules/bookings/bookings.routes';
import queuesRoutes from './modules/queues/queues.routes';
import paymentsRoutes from './modules/payments/payments.routes';
import reviewsRoutes from './modules/reviews/reviews.routes';
import aiRoutes from './modules/ai/ai.routes';
import settingsRoutes from './modules/settings/settings.routes';
import dashboardRoutes from './modules/dashboard/dashboard.routes';
import { errorHandler, notFoundHandler } from './middlewares/errorHandler';

const app = express();

app.use(helmet());
app.use(
  cors({
    origin: env.corsOrigin,
    credentials: true,
  })
);
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

if (env.nodeEnv !== 'test') {
  app.use(morgan('dev'));
}

// Swagger API Documentation
app.get('/api-docs.json', (_req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.send(swaggerSpec);
});
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

// API Routes
app.use('/api/health', healthRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/accounts', accountsRoutes);
app.use('/api/barbers', barbersRoutes);
app.use('/api/services', servicesRoutes);
app.use('/api/products', productsRoutes);
app.use('/api/hairstyles', hairstylesRoutes);
app.use('/api/bookings', bookingsRoutes);
app.use('/api/queues', queuesRoutes);
app.use('/api/payments', paymentsRoutes);
app.use('/api/reviews', reviewsRoutes);
app.use('/api/ai', aiRoutes);
app.use('/api/settings', settingsRoutes);
app.use('/api/dashboard', dashboardRoutes);

// Error Handling
app.use(notFoundHandler);
app.use(errorHandler);

export default app;
