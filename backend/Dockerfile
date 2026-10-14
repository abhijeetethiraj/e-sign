# Base image: Official Node.js LTS running on lightweight, secure Alpine Linux
FROM node:20-alpine

# Set working directory inside container
WORKDIR /app

# Copy dependency manifests first to leverage Docker layer caching
COPY package*.json ./

# Install only production dependencies
RUN npm ci --omit=dev

# Copy application source code
COPY src/ ./src/

# Set production environment variables
ENV NODE_ENV=production
ENV PORT=8000

# Expose API port
EXPOSE 8000

# Switch to non-root user provided by node image for security hardening
USER node

# Health check to ensure the container is actively serving requests
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8000/api/health || exit 1

# Start the Node.js API server
CMD ["node", "src/server.js"]
