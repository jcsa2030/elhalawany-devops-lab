FROM node:22-alpine

LABEL org.opencontainers.image.source="https://github.com/jcsa2030/elhalawany-devops-lab"


# Create application directory
WORKDIR /app

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy application files
COPY . .

# Change ownership
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose application port
EXPOSE 3000

# Start application
CMD ["npm", "start"]