import path from 'path';
import swaggerJsdoc from 'swagger-jsdoc';
import { env } from './env';

const options: swaggerJsdoc.Options = {
  definition: {
    openapi: '3.0.3',
    info: {
      title: 'TRIM Backend API',
      version: '1.0.0',
      description:
        'REST API documentation for TRIM - AI-Powered Barbershop Information System',
    },
    servers: [
      {
        url: `http://localhost:${env.port}`,
        description: 'Local Development Server',
      },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
        },
      },
      schemas: {
        SuccessResponse: {
          type: 'object',
          properties: {
            success: { type: 'boolean', example: true },
            message: { type: 'string', example: 'OK' },
            data: { nullable: true },
          },
        },
        ErrorResponse: {
          type: 'object',
          properties: {
            success: { type: 'boolean', example: false },
            message: { type: 'string', example: 'Internal Server Error' },
            errors: { nullable: true },
          },
        },
      },
    },
  },
  apis: [
    path.join(__dirname, '../modules/**/*.routes.ts').replace(/\\/g, '/'),
    path.join(__dirname, '../modules/**/*.routes.js').replace(/\\/g, '/'),
  ],
};

export const swaggerSpec = swaggerJsdoc(options);

