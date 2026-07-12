FROM node:20-slim

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci --omit=dev

COPY . .

RUN chown -R node:node /app
USER node

ENV NODE_ENV=production
ENV PORT=3000
EXPOSE 3000

# Migrations and the supermarket seed are idempotent, so it's safe to run
# them on every start — a fresh deploy just needs `docker compose up -d`.
CMD ["sh", "-c", "node src/database/migrate.js && node src/database/seed.js && node src/api/server.js"]
