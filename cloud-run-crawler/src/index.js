// Polyfill for Node.js 18 compatibility with undici/axios
if (typeof globalThis.File === 'undefined') {
  globalThis.File = class File extends Blob {
    constructor(bits, name, options = {}) {
      super(bits, options);
      this.name = name;
      this.lastModified = options.lastModified || Date.now();
    }
  };
}

if (typeof globalThis.FormData === 'undefined') {
  globalThis.FormData = class FormData {
    constructor() {
      this._data = new Map();
    }
    append(key, value) {
      this._data.set(key, value);
    }
    get(key) {
      return this._data.get(key);
    }
  };
}

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const logger = require('./logger');
const CrawlerService = require('./crawler-service');

// Initialize Firebase Admin
const firebaseApp = initializeApp({
  storageBucket: 'zenradar-acb85.firebasestorage.app'
});
const db = getFirestore();

const app = express();
const port = process.env.PORT || 8080;

// Middleware
app.use(helmet());
app.use(compression());
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Request logging middleware
app.use((req, res, next) => {
  logger.info('Incoming request', {
    method: req.method,
    url: req.url,
    userAgent: req.get('User-Agent'),
    ip: req.ip,
    hasAuth: !!req.get('Authorization')
  });
  next();
});

// Authentication middleware for /crawl endpoint
async function authenticateToken(req, res, next) {
  const authHeader = req.get('Authorization');
  
  // For debugging: log all headers
  logger.info('Authentication attempt', {
    hasAuthHeader: !!authHeader,
    authHeaderValue: authHeader ? authHeader.substring(0, 20) + '...' : 'none',
    allHeaders: Object.keys(req.headers),
    url: req.url
  });
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    logger.warn('Missing or invalid Authorization header', {
      authHeader: authHeader ? 'present but invalid format' : 'missing',
      url: req.url
    });
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Missing or invalid Authorization header'
    });
  }

  // For now, let's temporarily accept any Bearer token to debug the issue
  // TODO: Implement proper token validation
  logger.info('Temporarily accepting Bearer token for debugging');
  next();
}

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version || '1.0.0'
  });
});

// Main crawl endpoint
app.post('/crawl', authenticateToken, async (req, res) => {
  const startTime = Date.now();
  const { requestId, triggerType, sites, userId } = req.body;

  if (!requestId || !triggerType) {
    return res.status(400).json({
      error: 'Missing required fields: requestId, triggerType'
    });
  }

  logger.info('Starting crawl job', {
    requestId,
    triggerType,
    sites: sites?.length || 'all',
    userId: userId || 'system'
  });

  try {
    // Update crawl request status
    await updateCrawlRequestStatus(requestId, 'running', {
      startedAt: new Date(),
      cloudRunJobId: `job_${requestId}_${Date.now()}`
    });

    // Initialize crawler service
    const crawler = new CrawlerService(db, logger);
    
    // Perform the crawl
    const results = await crawler.crawlSites(sites || []);
    
    const endTime = Date.now();
    const duration = endTime - startTime;

    logger.info('Crawl job completed', {
      requestId,
      duration: `${duration}ms`,
      productsFound: results.totalProducts,
      stockUpdates: results.stockUpdates,
      errors: results.errors?.length || 0
    });

    // Update crawl request status with results
    await updateCrawlRequestStatus(requestId, 'completed', {
      completedAt: new Date(),
      duration,
      totalProducts: results.totalProducts,
      stockUpdates: results.stockUpdates,
      sitesProcessed: results.sitesProcessed,
      results: {
        totalProducts: results.totalProducts,
        stockUpdates: results.stockUpdates,
        sitesProcessed: results.sitesProcessed,
        errors: results.errors
      }
    });

    // Respond with success
    res.status(200).json({
      success: true,
      jobId: `job_${requestId}_${startTime}`,
      requestId,
      duration,
      results: {
        totalProducts: results.totalProducts,
        stockUpdates: results.stockUpdates,
        sitesProcessed: results.sitesProcessed
      }
    });

  } catch (error) {
    const endTime = Date.now();
    const duration = endTime - startTime;

    logger.error('Crawl job failed', {
      requestId,
      duration: `${duration}ms`,
      error: error.message,
      stack: error.stack
    });

    // Update crawl request status with error
    await updateCrawlRequestStatus(requestId, 'failed', {
      failedAt: new Date(),
      duration,
      error: error.message
    });

    res.status(500).json({
      success: false,
      error: 'Crawl job failed',
      requestId,
      duration,
      details: error.message
    });
  }
});

// Error handling middleware
app.use((error, req, res, next) => {
  logger.error('Unhandled error', {
    error: error.message,
    stack: error.stack,
    url: req.url,
    method: req.method
  });

  res.status(500).json({
    error: 'Internal server error',
    timestamp: new Date().toISOString()
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Endpoint not found',
    path: req.originalUrl
  });
});

/**
 * Update crawl request status in Firestore
 */
async function updateCrawlRequestStatus(requestId, status, additionalData = {}) {
  try {
    await db.collection('crawl_requests').doc(requestId).update({
      status,
      updatedAt: new Date(),
      ...additionalData
    });
  } catch (error) {
    logger.error('Failed to update crawl request status', {
      requestId,
      status,
      error: error.message
    });
  }
}

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  process.exit(0);
});

// Start server
app.listen(port, () => {
  logger.info('ZenRadar Cloud Crawler started', {
    port,
    nodeVersion: process.version,
    platform: process.platform,
    memory: process.memoryUsage()
  });
});

module.exports = app;
