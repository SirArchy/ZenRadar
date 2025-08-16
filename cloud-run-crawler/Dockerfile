# ZenRadar Cloud Run Crawler

FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy source code
COPY src/ ./src/

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001
USER nodejs

# Expose port
EXPOSE 8080

# Set environment variable for port
ENV PORT=8080

# Start the application using npm script (includes --experimental-global-web flag)
CMD ["npm", "start"]
