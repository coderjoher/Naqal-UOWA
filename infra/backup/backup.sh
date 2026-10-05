#!/bin/sh
# Nightly PostgreSQL backup (P8). Custom-format dump, kept for KEEP_DAYS days, optionally copied
# off the server with rclone (BACKUP_REMOTE, e.g. "s3:naql-backups").
#   docker compose --profile backup up -d backup      (runs every night at BACKUP_HOUR Baghdad time)
#   docker compose run --rm backup now                (one backup immediately)
set -eu
DIR=${BACKUP_DIR:-/backups}
KEEP_DAYS=${KEEP_DAYS:-14}
mkdir -p "$DIR"

dump() {
  file="$DIR/naql-$(date -u +%Y%m%dT%H%M%SZ).dump"
  start=$(date +%s)
  pg_dump --format=custom --compress=9 --no-owner --file="$file.part" "$DATABASE_URL"
  mv "$file.part" "$file"
  # Prove the file is a readable archive before calling it a backup.
  pg_restore --list "$file" > /dev/null
  echo "$(date -u +%FT%TZ) backup $file ($(du -h "$file" | cut -f1), $(( $(date +%s) - start )) s)"
  find "$DIR" -name 'naql-*.dump' -mtime +"$KEEP_DAYS" -delete
  if [ -n "${BACKUP_REMOTE:-}" ]; then rclone copy "$file" "$BACKUP_REMOTE" && echo "copied to $BACKUP_REMOTE"; fi
}

if [ "${1:-}" = "now" ]; then dump; exit 0; fi

HOUR=${BACKUP_HOUR:-3}
echo "Nightly backups at ${HOUR}:00 Baghdad into $DIR (kept $KEEP_DAYS days)"
while true; do
  # Seconds until the next HOUR:00 in Asia/Baghdad (UTC+3, no DST).
  now=$(( $(date -u +%s) + 3 * 3600 ))
  next=$(( (now / 86400) * 86400 + HOUR * 3600 ))
  [ "$next" -le "$now" ] && next=$(( next + 86400 ))
  sleep $(( next - now ))
  dump || echo "$(date -u +%FT%TZ) BACKUP FAILED" >&2
done
