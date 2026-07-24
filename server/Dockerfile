# ─── Stage 1: Build ──────────────────────────────────────────────
FROM node:22-alpine AS builder

WORKDIR /app

# Зависимости
COPY package.json package-lock.json* ./
RUN npm ci

# Генерация Prisma клиента
COPY prisma ./prisma
RUN npx prisma generate

# Копирование исходного кода
COPY . .

# Сборка TypeScript
RUN npm run build

# ─── Stage 2: Production ─────────────────────────────────────────
FROM node:22-alpine AS runner

WORKDIR /app

# Только production зависимости
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev

# Скомпилированный код
COPY --from=builder /app/dist ./dist

# Strip debug artifacts (source maps, declarations) из production
RUN find ./dist -name '*.map' -delete && \
    find ./dist -name '*.d.ts' -delete && \
    find ./dist -name '*.d.ts.map' -delete

# Prisma
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/prisma ./prisma

# Non-root user
RUN addgroup -g 1001 -S charo && \
    adduser -S charo -u 1001 -G charo
USER charo

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

CMD ["node", "dist/index.js"]
