# 🌐 API Gateway - Multi-Cluster E-Commerce Platform
# Node.js with Express and advanced middleware

FROM node:18-alpine AS builder

# Install security updates
RUN apk update && apk upgrade && apk add --no-cache dumb-init

# Create app directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy source code
COPY src/ ./src/
COPY tsconfig.json ./

# Build TypeScript
RUN npm run build

# Production stage
FROM node:18-alpine

# Install security updates and curl for health checks
RUN apk update && apk upgrade && apk add --no-cache dumb-init curl

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S apigateway -u 1001

# Create app directory
WORKDIR /app

# Copy built application
COPY --from=builder --chown=apigateway:nodejs /app/dist ./dist
COPY --from=builder --chown=apigateway:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=apigateway:nodejs /app/package*.json ./

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

# Switch to non-root user
USER apigateway

# Expose port
EXPOSE 8080

# Add labels for Istio and observability
LABEL app="api-gateway" \
      version="v1.0.0" \
      component="gateway" \
      tier="backend"

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/index.js"]
