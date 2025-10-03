import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import { createProxyMiddleware } from 'http-proxy-middleware';
import promClient from 'prom-client';
import swaggerUi from 'swagger-ui-express';
import YAML from 'yamljs';
import 'express-async-errors';

// Internal imports
import { logger } from './utils/logger';
import { errorHandler } from './middleware/errorHandler';
import { authMiddleware } from './middleware/auth';
import { metricsMiddleware } from './middleware/metrics';
import { healthRouter } from './routes/health';
import { authRouter } from './routes/auth';
import { redisClient } from './utils/redis';

// Configuration
const PORT = process.env.PORT || 3001;
const NODE_ENV = process.env.NODE_ENV || 'development';

// Service endpoints
const SERVICES = {
  USER_SERVICE: process.env.USER_SERVICE_URL || 'http://user-service:3002',
  PRODUCT_SERVICE: process.env.PRODUCT_SERVICE_URL || 'http://product-service:3003',
  ORDER_SERVICE: process.env.ORDER_SERVICE_URL || 'http://order-service:3004',
  PAYMENT_SERVICE: process.env.PAYMENT_SERVICE_URL || 'http://payment-service:3005',
  NOTIFICATION_SERVICE: process.env.NOTIFICATION_SERVICE_URL || 'http://notification-service:3006',
  ANALYTICS_SERVICE: process.env.ANALYTICS_SERVICE_URL || 'http://analytics-service:3007',
};

// Create Express app
const app = express();

// ===============================================================================
// MIDDLEWARE SETUP
// ===============================================================================

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
}));

// CORS configuration
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
}));

// Compression and parsing
app.use(compression());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Logging
app.use(morgan('combined', {
  stream: { write: (message) => logger.info(message.trim()) }
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // Limit each IP to 1000 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(limiter);

// Metrics middleware
app.use(metricsMiddleware);

// ===============================================================================
// PROMETHEUS METRICS
// ===============================================================================

// Create a Registry to register the metrics
const register = new promClient.Registry();

// Add default metrics
promClient.collectDefaultMetrics({
  register,
  prefix: 'api_gateway_',
});

// Custom metrics
const httpRequestDuration = new promClient.Histogram({
  name: 'api_gateway_http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10],
});

const httpRequestTotal = new promClient.Counter({
  name: 'api_gateway_http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
});

register.registerMetric(httpRequestDuration);
register.registerMetric(httpRequestTotal);

// ===============================================================================
// API DOCUMENTATION
// ===============================================================================

// Load Swagger documentation
const swaggerDocument = YAML.load('./swagger.yaml') || {
  openapi: '3.0.0',
  info: {
    title: 'E-commerce API Gateway',
    version: '1.0.0',
    description: 'API Gateway for E-commerce Microservices',
  },
  servers: [
    {
      url: '/api/v1',
      description: 'API Gateway',
    },
  ],
};

app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument));

// ===============================================================================
// ROUTES
// ===============================================================================

// Health check routes
app.use('/health', healthRouter);

// Authentication routes
app.use('/api/v1/auth', authRouter);

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// ===============================================================================
// SERVICE PROXIES
// ===============================================================================

// User Service Proxy
app.use('/api/v1/users', authMiddleware, createProxyMiddleware({
  target: SERVICES.USER_SERVICE,
  changeOrigin: true,
  pathRewrite: {
    '^/api/v1/users': '/api/v1/users',
  },
  onProxyReq: (proxyReq, req) => {
    // Add user context to headers
    if (req.user) {
      proxyReq.setHeader('X-User-ID', req.user.id);
      proxyReq.setHeader('X-User-Role', req.user.role);
    }
  },
  onError: (err, req, res) => {
    logger.error('User Service Proxy Error:', err);
    res.status(503).json({ error: 'User service unavailable' });
  },
}));

// Product Service Proxy
app.use('/api/v1/products', createProxyMiddleware({
  target: SERVICES.PRODUCT_SERVICE,
  changeOrigin: true,
  pathRewrite: {
    '^/api/v1/products': '/api/v1/products',
  },
  onError: (err, req, res) => {
    logger.error('Product Service Proxy Error:', err);
    res.status(503).json({ error: 'Product service unavailable' });
  },
}));

// Order Service Proxy
app.use('/api/v1/orders', authMiddleware, createProxyMiddleware({
  target: SERVICES.ORDER_SERVICE,
  changeOrigin: true,
  pathRewrite: {
    '^/api/v1/orders': '/api/v1/orders',
  },
  onProxyReq: (proxyReq, req) => {
    if (req.user) {
      proxyReq.setHeader('X-User-ID', req.user.id);
      proxyReq.setHeader('X-User-Role', req.user.role);
    }
  },
  onError: (err, req, res) => {
    logger.error('Order Service Proxy Error:', err);
    res.status(503).json({ error: 'Order service unavailable' });
  },
}));

// Payment Service Proxy
app.use('/api/v1/payments', authMiddleware, createProxyMiddleware({
  target: SERVICES.PAYMENT_SERVICE,
  changeOrigin: true,
  pathRewrite: {
    '^/api/v1/payments': '/api/v1/payments',
  },
  onProxyReq: (proxyReq, req) => {
    if (req.user) {
      proxyReq.setHeader('X-User-ID', req.user.id);
      proxyReq.setHeader('X-User-Role', req.user.role);
    }
  },
  onError: (err, req, res) => {
    logger.error('Payment Service Proxy Error:', err);
    res.status(503).json({ error: 'Payment service unavailable' });
  },
}));

// Notification Service Proxy
app.use('/api/v1/notifications', authMiddleware, createProxyMiddleware({
  target: SERVICES.NOTIFICATION_SERVICE,
  changeOrigin: true,
  pathRewrite: {
    '^/api/v1/notifications': '/api/v1/notifications',
  },
  onProxyReq: (proxyReq, req) => {
    if (req.user) {
      proxyReq.setHeader('X-User-ID', req.user.id);
      proxyReq.setHeader('X-User-Role', req.user.role);
    }
  },
  onError: (err, req, res) => {
    logger.error('Notification Service Proxy Error:', err);
    res.status(503).json({ error: 'Notification service unavailable' });
  },
}));

// Analytics Service Proxy
app.use('/api/v1/analytics', authMiddleware, createProxyMiddleware({
  target: SERVICES.ANALYTICS_SERVICE,
  changeOrigin: true,
  pathRewrite: {
    '^/api/v1/analytics': '/api/v1/analytics',
  },
  onProxyReq: (proxyReq, req) => {
    if (req.user) {
      proxyReq.setHeader('X-User-ID', req.user.id);
      proxyReq.setHeader('X-User-Role', req.user.role);
    }
  },
  onError: (err, req, res) => {
    logger.error('Analytics Service Proxy Error:', err);
    res.status(503).json({ error: 'Analytics service unavailable' });
  },
}));

// ===============================================================================
// ERROR HANDLING
// ===============================================================================

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: `Route ${req.originalUrl} not found`,
    timestamp: new Date().toISOString(),
  });
});

// Global error handler
app.use(errorHandler);

// ===============================================================================
// GRACEFUL SHUTDOWN
// ===============================================================================

const gracefulShutdown = async (signal: string) => {
  logger.info(`Received ${signal}. Starting graceful shutdown...`);
  
  // Close Redis connection
  if (redisClient.isOpen) {
    await redisClient.quit();
    logger.info('Redis connection closed');
  }
  
  // Close server
  server.close(() => {
    logger.info('HTTP server closed');
    process.exit(0);
  });
  
  // Force close after 10 seconds
  setTimeout(() => {
    logger.error('Could not close connections in time, forcefully shutting down');
    process.exit(1);
  }, 10000);
};

// ===============================================================================
// START SERVER
// ===============================================================================

const server = app.listen(PORT, () => {
  logger.info(`API Gateway started on port ${PORT}`);
  logger.info(`Environment: ${NODE_ENV}`);
  logger.info(`API Documentation: http://localhost:${PORT}/api-docs`);
  logger.info(`Health Check: http://localhost:${PORT}/health`);
  logger.info(`Metrics: http://localhost:${PORT}/metrics`);
});

// Handle graceful shutdown
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

export default app;
