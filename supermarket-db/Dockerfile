FROM node:20-slim

WORKDIR /app

# Keep Playwright's browser download inside /app so it survives the
# chown below — the default (~/.cache) is under root's home, which the
# unprivileged "node" user can't read at runtime.
ENV PLAYWRIGHT_BROWSERS_PATH=/app/.cache/ms-playwright

COPY package.json package-lock.json* ./
RUN npm ci --omit=dev

# Chromium's shared-library dependencies aren't part of node:20-slim;
# --with-deps apt-get installs exactly what this Playwright version needs
# (must run as root, before the USER switch below).
RUN npx playwright install --with-deps chromium

COPY . .

RUN chown -R node:node /app
USER node

ENV NODE_ENV=production
ENV PORT=3000
EXPOSE 3000

# Migrations and the supermarket seed are idempotent, so it's safe to run
# them on every start — a fresh deploy just needs `docker compose up -d`.
CMD ["sh", "-c", "node src/database/migrate.js && node src/database/seed.js && node src/api/server.js"]
