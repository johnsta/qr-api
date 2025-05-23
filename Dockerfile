FROM node:18-slim

WORKDIR /app

COPY package*.json ./
RUN npm install --production

# Copy application code
COPY app.js .
# Copy example environment file (can be overridden by environment variables)
COPY .env.example .env

# Command to run the application
CMD ["node", "app.js"]
