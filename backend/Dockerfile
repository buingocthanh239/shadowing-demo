FROM node:24-alpine
WORKDIR /app
ENV NODE_ENV=production

COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY src ./src
COPY scripts ./scripts
COPY db ./db

# media/ và data/ được mount từ host (không đóng vào image), uploads/ là volume
RUN mkdir -p media data uploads && chown -R node:node /app
USER node

EXPOSE 4100
HEALTHCHECK --interval=10s --timeout=3s --start-period=20s \
  CMD wget -qO- http://127.0.0.1:4100/api/health || exit 1

# Seed lần đầu (nếu DB trống) rồi chạy API
CMD ["sh", "-c", "node scripts/seed.js --if-empty && exec node src/server.js"]
