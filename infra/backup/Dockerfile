# Backup runner: PostgreSQL 16 client tools + rclone for off-site copies.
FROM postgres:16-alpine
RUN apk add --no-cache rclone tzdata
COPY backup.sh restore-drill.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/backup.sh /usr/local/bin/restore-drill.sh
ENTRYPOINT ["/bin/sh", "-c", "if [ \"$0\" = restore-drill ]; then exec restore-drill.sh \"$@\"; else exec backup.sh \"$0\" \"$@\"; fi"]
CMD ["schedule"]
