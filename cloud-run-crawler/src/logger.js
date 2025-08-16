const winston = require('winston');

// Create logger instance
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: {
    service: 'zenradar-crawler'
  },
  transports: [
    // Console transport for Cloud Run logs
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    })
  ]
});

// Only add file transport for local development (not in production)
if (process.env.NODE_ENV !== 'production') {
  try {
    logger.add(new winston.transports.File({ 
      filename: 'logs/error.log', 
      level: 'error' 
    }));
    logger.add(new winston.transports.File({ 
      filename: 'logs/combined.log' 
    }));
  } catch (error) {
    // Silently fail if we can't create file logs in production
    console.warn('Could not create file logs:', error.message);
  }
}

module.exports = logger;
