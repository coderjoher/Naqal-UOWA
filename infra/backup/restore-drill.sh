#!/bin/sh
# Weekly restore drill (P8 exit gate: < 1 hour). Restores the newest backup into a scratch
# database, checks it, and prints how long it took. Nothing in the live database is touched.
#   docker compose run --rm backup restore-drill
#   DATABASE_URL=… BACKUP_DIR=… sh infra/backup/restore-drill.sh      (outside Docker)
set -eu
DIR=${BACKUP_DIR:-/backups}
file=${1:-$(ls -1t "$DIR"/naql-*.dump 2>/dev/null | head -1)}
[ -n "$file" ] && [ -f "$file" ] || { echo "No backup found in $DIR"; exit 1; }

start=$(date +%s)
scratch="naql_restore_drill_$(date +%s)"
admin=$(echo "$DATABASE_URL" | sed -E 's#/[^/?]+(\?|$)#/postgres\1#')
target=$(echo "$DATABASE_URL" | sed -E "s#/[^/?]+(\?|$)#/$scratch\1#")
psql "$admin" -qc "CREATE DATABASE $scratch"
trap 'psql "$admin" -qc "DROP DATABASE IF EXISTS $scratch" > /dev/null' EXIT

pg_restore --no-owner --exit-on-error --dbname="$target" "$file"

# The restored database must hold the same money and people as the backup claims, and the
# append-only protections must have come back with it.
q() { psql "$target" -tAc "$1"; }
for t in universities users payments subscriptions runs settlements; do
  printf '  %-14s %s rows\n' "$t" "$(q "SELECT count(*) FROM $t")"
done
triggers=$(q "SELECT count(*) FROM pg_trigger WHERE tgname IN ('payments_immutable', 'settlements_immutable_when_approved')")
[ "$triggers" = "2" ] || { echo "Immutability triggers missing after restore"; exit 1; }
migrations=$(q "SELECT count(*) FROM _prisma_migrations WHERE finished_at IS NOT NULL")
[ "$migrations" -gt 0 ] || { echo "No schema history in the backup"; exit 1; }
balance=$(q "SELECT coalesce(sum(amount), 0) FROM payments")

secs=$(( $(date +%s) - start ))
echo "Restore drill OK: $(basename "$file") restored in ${secs} s; payments total ${balance} IQD; ${migrations} migrations."
[ "$secs" -lt 3600 ] || { echo "Restore took longer than 1 hour"; exit 1; }
