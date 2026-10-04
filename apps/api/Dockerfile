# Build context: repository root (see docker-compose.yml).
FROM node:22-slim AS base
RUN apt-get update && apt-get install -y --no-install-recommends openssl ca-certificates && rm -rf /var/lib/apt/lists/* \
  && corepack enable
WORKDIR /repo

FROM base AS build
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/api/package.json apps/api/
RUN pnpm install --frozen-lockfile --filter @naql/api
COPY apps/api apps/api
RUN pnpm --filter @naql/api exec prisma generate && pnpm --filter @naql/api build

FROM base AS runtime
ENV NODE_ENV=production
COPY --from=build /repo /repo
WORKDIR /repo/apps/api
EXPOSE 3000
# Migrations run on start so a fresh `docker compose up` is usable immediately; with
# DEMO_SEED=true the demo data is loaded once (the seed skips itself when data exists).
CMD ["sh", "-c", "npx prisma migrate deploy && if [ \"$DEMO_SEED\" = true ]; then npx ts-node prisma/seed-demo.ts; fi && node dist/main.js"]
