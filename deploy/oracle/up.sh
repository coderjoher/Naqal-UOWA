#!/usr/bin/env sh
# Starts (or updates) the whole stack on a public server: HTTPS (Caddy) + nightly backups.
#   ./deploy/oracle/up.sh            first start, and after every `git pull`
# Settings come from .env in the repository root (see docs/DEPLOY-ORACLE.md).
set -eu
cd "$(dirname "$0")/../.."
[ -f .env ] || { echo "Missing .env — copy deploy/oracle/env.example to .env and fill it in." >&2; exit 1; }
exec docker compose -f docker-compose.yml -f deploy/oracle/compose.server.yml \
  --profile https --profile backup up -d --build --wait "$@"
