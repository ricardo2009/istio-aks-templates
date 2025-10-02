import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import compression from 'compression';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import slowDown from 'express-slow-down';
import { createProxyMiddleware } from 'http-proxy-middleware';
import { v4 as uuidv4 } from 'uuid';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import Joi from 'joi';
import winston from 'winston';
import { register, collectDefaultMetrics, Counter, Histogram, Gauge } from 'prom-client';
import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { Resource } from '@opentelemetry/resources';
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

// 📊 Initialize OpenTelemetry
const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'api-gateway',
    [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
    [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: process.env.NODE_ENV || 'development',
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();

// 📝 Configure Winston Logger
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: 'api-gateway' },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    })
  ],
});

// 📊 Prometheus Metrics
collectDefaultMetrics();

const httpRequestsTotal = new Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code', 'user_type'],
});

const httpRequestDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10],
});

const activeConnections = new Gauge({
  name: 'active_connections',
  help: 'Number of active connections',
});

const crossClusterRequests = new Counter({
  name: 'cross_cluster_requests_total',
  help: 'Total number of cross-cluster requests',
  labelNames: ['source_cluster', 'target_cluster', 'service'],
});

// 🔧 Configuration
const config = {
  port: parseInt(process.env.PORT || '8080'),
  jwtSecret: process.env.JWT_SECRET || 'your-super-secret-jwt-key',
  services: {
    userService: process.env.USER_SERVICE_URL || 'http://user-service:3001',
    orderService: process.env.ORDER_SERVICE_URL || 'http://order-service:8081',
    paymentService: process.env.PAYMENT_SERVICE_URL || 'http://payment-service:8000',
    notificationService: process.env.NOTIFICATION_SERVICE_URL || 'http://notification-service:8082',
    auditService: process.env.AUDIT_SERVICE_URL || 'http://audit-service:5000',
    reportingService: process.env.REPORTING_SERVICE_URL || 'http://reporting-service:8001',
  },
  clusters: {
    primary: process.env.PRIMARY_CLUSTER || 'aks-labs',
    secondary: process.env.SECONDARY_CLUSTER || 'aks-labs-secondary',
  }
};

// 🚀 Initialize Express App
const app = express();

// 🛡️ Security Middleware
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

// 🌐 CORS Configuration
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'X-User-Type', 'X-Trace-ID', 'X-AB-Test-Group'],
}));

// 🗜️ Compression
app.use(compression());

// 📝 Request Logging
app.use(morgan('combined', {
  stream: {
    write: (message: string) => logger.info(message.trim())
  }
}));

// 🚦 Rate Limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // limit each IP to 1000 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});

const speedLimiter = slowDown({
  windowMs: 15 * 60 * 1000, // 15 minutes
  delayAfter: 100, // allow 100 requests per 15 minutes, then...
  delayMs: 500, // begin adding 500ms of delay per request above 100
});

app.use(limiter);
app.use(speedLimiter);

// 📊 Metrics Middleware
app.use((req, res, next) => {
  const start = Date.now();
  activeConnections.inc();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const userType = req.headers['x-user-type'] as string || 'anonymous';
    
    httpRequestsTotal.inc({
      method: req.method,
      route: req.route?.path || req.path,
      status_code: res.statusCode,
      user_type: userType,
    });
    
    httpRequestDuration.observe({
      method: req.method,
      route: req.route?.path || req.path,
      status_code: res.statusCode,
    }, duration);
    
    activeConnections.dec();
  });
  
  next();
});

// 🔍 Request ID and Tracing
app.use((req, res, next) => {
  const requestId = req.headers['x-request-id'] as string || uuidv4();
  const traceId = req.headers['x-trace-id'] as string || uuidv4();
  
  req.headers['x-request-id'] = requestId;
  req.headers['x-trace-id'] = traceId;
  
  res.setHeader('X-Request-ID', requestId);
  res.setHeader('X-Trace-ID', traceId);
  
  next();
});

// 📦 Body Parser
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// 🏥 Health Check Endpoints
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: '1.0.0',
    service: 'api-gateway',
  });
});

app.get('/health/ready', (req, res) => {
  // Add readiness checks here (database connections, external services, etc.)
  res.status(200).json({
    status: 'ready',
    timestamp: new Date().toISOString(),
    checks: {
      database: 'ok',
      externalServices: 'ok',
    },
  });
});

app.get('/health/live', (req, res) => {
  res.status(200).json({
    status: 'alive',
    timestamp: new Date().toISOString(),
  });
});

// 📊 Metrics Endpoint
app.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  } catch (error) {
    res.status(500).end(error);
  }
});

// 🔐 Authentication Middleware
const authenticateToken = (req: express.Request, res: express.Response, next: express.NextFunction) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  jwt.verify(token, config.jwtSecret, (err: any, user: any) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid or expired token' });
    }
    (req as any).user = user;
    next();
  });
};

// 🎯 Service Health Dashboard
app.get('/api/health/services', async (req, res) => {
  const services = [
    { name: 'user-service', url: config.services.userService, cluster: config.clusters.primary },
    { name: 'order-service', url: config.services.orderService, cluster: config.clusters.primary },
    { name: 'payment-service', url: config.services.paymentService, cluster: config.clusters.secondary },
    { name: 'notification-service', url: config.services.notificationService, cluster: config.clusters.secondary },
    { name: 'audit-service', url: config.services.auditService, cluster: config.clusters.secondary },
    { name: 'reporting-service', url: config.services.reportingService, cluster: config.clusters.secondary },
  ];

  const healthChecks = await Promise.all(
    services.map(async (service) => {
      try {
        const start = Date.now();
        // Simulate health check (in real implementation, make actual HTTP calls)
        await new Promise(resolve => setTimeout(resolve, Math.random() * 100));
        const responseTime = Date.now() - start;
        
        const status = Math.random() > 0.1 ? 'healthy' : (Math.random() > 0.5 ? 'degraded' : 'unhealthy');
        
        return {
          service: service.name,
          status,
          cluster: service.cluster,
          responseTime,
          lastCheck: new Date().toISOString(),
        };
      } catch (error) {
        return {
          service: service.name,
          status: 'unhealthy',
          cluster: service.cluster,
          responseTime: 0,
          lastCheck: new Date().toISOString(),
          error: 'Connection failed',
        };
      }
    })
  );

  res.json(healthChecks);
});

// 👤 User Service Proxy
app.use('/api/users', createProxyMiddleware({
  target: config.services.userService,
  changeOrigin: true,
  pathRewrite: {
    '^/api/users': '/api/users',
  },
  onProxyReq: (proxyReq, req, res) => {
    // Add cross-cluster tracking
    crossClusterRequests.inc({
      source_cluster: config.clusters.primary,
      target_cluster: config.clusters.primary,
      service: 'user-service',
    });
    
    // Add tracing headers
    proxyReq.setHeader('X-Source-Service', 'api-gateway');
    proxyReq.setHeader('X-Request-ID', req.headers['x-request-id'] as string);
    proxyReq.setHeader('X-Trace-ID', req.headers['x-trace-id'] as string);
  },
  onError: (err, req, res) => {
    logger.error('User service proxy error:', err);
    res.status(503).json({ error: 'User service unavailable' });
  },
}));

// 🛒 Order Service Proxy
app.use('/api/orders', createProxyMiddleware({
  target: config.services.orderService,
  changeOrigin: true,
  pathRewrite: {
    '^/api/orders': '/api/orders',
  },
  onProxyReq: (proxyReq, req, res) => {
    crossClusterRequests.inc({
      source_cluster: config.clusters.primary,
      target_cluster: config.clusters.primary,
      service: 'order-service',
    });
    
    proxyReq.setHeader('X-Source-Service', 'api-gateway');
    proxyReq.setHeader('X-Request-ID', req.headers['x-request-id'] as string);
    proxyReq.setHeader('X-Trace-ID', req.headers['x-trace-id'] as string);
  },
  onError: (err, req, res) => {
    logger.error('Order service proxy error:', err);
    res.status(503).json({ error: 'Order service unavailable' });
  },
}));

// 💳 Payment Service Proxy (Cross-Cluster)
app.use('/api/payments', createProxyMiddleware({
  target: config.services.paymentService,
  changeOrigin: true,
  pathRewrite: {
    '^/api/payments': '/api/payments',
  },
  onProxyReq: (proxyReq, req, res) => {
    crossClusterRequests.inc({
      source_cluster: config.clusters.primary,
      target_cluster: config.clusters.secondary,
      service: 'payment-service',
    });
    
    proxyReq.setHeader('X-Source-Service', 'api-gateway');
    proxyReq.setHeader('X-Source-Cluster', config.clusters.primary);
    proxyReq.setHeader('X-Target-Cluster', config.clusters.secondary);
    proxyReq.setHeader('X-Request-ID', req.headers['x-request-id'] as string);
    proxyReq.setHeader('X-Trace-ID', req.headers['x-trace-id'] as string);
  },
  onError: (err, req, res) => {
    logger.error('Payment service proxy error:', err);
    res.status(503).json({ error: 'Payment service unavailable' });
  },
}));

// 🧪 Chaos Engineering Endpoints
app.post('/api/chaos/:testType', (req, res) => {
  const { testType } = req.params;
  const testId = uuidv4();
  
  logger.info(`Starting chaos test: ${testType}`, { testId, testType });
  
  // Simulate chaos test execution
  setTimeout(() => {
    logger.info(`Chaos test completed: ${testType}`, { testId, testType });
  }, 30000);
  
  res.json({
    testId,
    testType,
    status: 'started',
    estimatedDuration: 30,
    timestamp: new Date().toISOString(),
  });
});

app.get('/api/chaos/results', (req, res) => {
  // Simulate chaos test results
  const results = [
    {
      type: 'network-delay',
      status: 'success',
      duration: 30,
      impact: 'minimal',
      recoveryTime: 5,
      timestamp: new Date(Date.now() - 300000).toISOString(),
    },
    {
      type: 'service-failure',
      status: 'partial',
      duration: 45,
      impact: 'moderate',
      recoveryTime: 12,
      timestamp: new Date(Date.now() - 600000).toISOString(),
    },
  ];
  
  res.json(results);
});

// 🔍 API Documentation
app.get('/api/docs', (req, res) => {
  res.json({
    name: 'Multi-Cluster E-Commerce API Gateway',
    version: '1.0.0',
    description: 'API Gateway for demonstrating Istio Service Mesh capabilities',
    endpoints: {
      health: {
        '/health': 'Basic health check',
        '/health/ready': 'Readiness probe',
        '/health/live': 'Liveness probe',
        '/api/health/services': 'Service health dashboard',
      },
      services: {
        '/api/users': 'User management (Cluster 1)',
        '/api/orders': 'Order management (Cluster 1)',
        '/api/payments': 'Payment processing (Cluster 2)',
      },
      chaos: {
        'POST /api/chaos/:testType': 'Start chaos engineering test',
        'GET /api/chaos/results': 'Get chaos test results',
      },
      monitoring: {
        '/metrics': 'Prometheus metrics',
      },
    },
    features: [
      'Cross-cluster service communication',
      'mTLS security',
      'Distributed tracing',
      'Circuit breakers',
      'Rate limiting',
      'Chaos engineering',
    ],
  });
});

// 🚫 404 Handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: `Route ${req.originalUrl} not found`,
    timestamp: new Date().toISOString(),
  });
});

// 🚨 Error Handler
app.use((error: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  logger.error('Unhandled error:', error);
  
  res.status(error.status || 500).json({
    error: 'Internal Server Error',
    message: process.env.NODE_ENV === 'development' ? error.message : 'Something went wrong',
    timestamp: new Date().toISOString(),
    requestId: req.headers['x-request-id'],
  });
});

// 🚀 Start Server
const server = app.listen(config.port, '0.0.0.0', () => {
  logger.info(`🚀 API Gateway started on port ${config.port}`);
  logger.info(`📊 Metrics available at http://localhost:${config.port}/metrics`);
  logger.info(`🏥 Health check at http://localhost:${config.port}/health`);
  logger.info(`📚 API docs at http://localhost:${config.port}/api/docs`);
});

// 🛑 Graceful Shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  server.close(() => {
    logger.info('Process terminated');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  server.close(() => {
    logger.info('Process terminated');
    process.exit(0);
  });
});

export default app;
