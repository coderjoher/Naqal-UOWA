# Build context: repository root (see docker-compose.yml).
FROM node:22-slim AS build
RUN corepack enable
WORKDIR /repo
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/dashboard/package.json apps/dashboard/
RUN pnpm install --frozen-lockfile --filter @naql/dashboard
COPY packages/design-tokens packages/design-tokens
COPY apps/dashboard apps/dashboard
ARG VITE_SENTRY_DSN=
ENV VITE_SENTRY_DSN=$VITE_SENTRY_DSN
# Map tiles (see docs/OPERATIONS.md); empty = OpenStreetMap.
ARG VITE_MAP_TILES=
ARG VITE_MAP_ATTRIBUTION=
ENV VITE_MAP_TILES=$VITE_MAP_TILES VITE_MAP_ATTRIBUTION=$VITE_MAP_ATTRIBUTION
RUN pnpm --filter @naql/dashboard build

FROM nginx:1.27-alpine
ARG VITE_MAP_TILES=
COPY apps/dashboard/nginx.conf /etc/nginx/conf.d/default.conf
# The CSP allows exactly the tile hosts the build uses.
RUN origins=$(echo "${VITE_MAP_TILES:-https://tile.openstreetmap.org/{z}/{x}/{y}.png}" | tr ',' '\n' \
      | sed -E 's#^[[:space:]]*(https://[^/]+).*#\1#' | sort -u | tr '\n' ' ') \
  && sed -i "s#__MAP_ORIGINS__#${origins% }#g" /etc/nginx/conf.d/default.conf \
  && ! grep -q __MAP_ORIGINS__ /etc/nginx/conf.d/default.conf
COPY --from=build /repo/apps/dashboard/dist /usr/share/nginx/html
EXPOSE 80
