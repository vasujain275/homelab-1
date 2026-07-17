#!/bin/bash
# Immich backup to Backblaze B2 via restic
# Run daily via systemd timer (immich-backup.timer) at 3 AM
#
# What gets backed up:
#   - library/   originals (external library imports)
#   - upload/    originals (mobile/browser uploads)
#   - profile/   user avatar images
#   - DB dump    PostgreSQL dump (gzipped), fresh per run
#
# What is skipped (regenerable):
#   - thumbs/         → regenerate: Administration > Jobs > Generate Thumbnails
#   - encoded-video/  → regenerate: Administration > Jobs > Transcode Videos
#   - backups/        → Immich auto DB dumps (redundant, this script does its own dump)
#   - postgres/       → raw pgdata (dump is safer and smaller)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.backup.env"
DUMP_FILE="/tmp/immich-db-$(date +%F-%H%M%S).sql.gz"

# ── Load secrets ──
if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: $ENV_FILE not found. Copy .backup.env.example and fill in secrets." >&2
    exit 1
fi
# shellcheck source=/dev/null
source "$ENV_FILE"

# ── Verify required env vars ──
for var in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY RESTIC_PASSWORD RESTIC_REPOSITORY; do
    if [[ -z "${!var:-}" ]]; then
        echo "ERROR: $var is not set in $ENV_FILE" >&2
        exit 1
    fi
done

echo "[$(date -Iseconds)] Starting Immich backup"

# ── 1. Dump database ──
echo "[$(date -Iseconds)] Dumping PostgreSQL database..."
docker exec immich_postgres \
    pg_dump --clean --if-exists --dbname=immich --username=postgres \
    | gzip > "$DUMP_FILE"

if [[ ! -s "$DUMP_FILE" ]]; then
    echo "ERROR: Database dump is empty. Aborting." >&2
    rm -f "$DUMP_FILE"
    exit 1
fi
echo "[$(date -Iseconds)] Database dump: $(du -h "$DUMP_FILE" | cut -f1)"

# ── 2. Backup originals + dump ──
echo "[$(date -Iseconds)] Running restic backup..."
restic backup \
    /home/vasu/services/immich/library \
    /home/vasu/services/immich/upload \
    /home/vasu/services/immich/profile \
    "$DUMP_FILE"

# ── 3. Cleanup local temp ──
rm -f "$DUMP_FILE"

# ── 4. Prune old snapshots ──
echo "[$(date -Iseconds)] Pruning old snapshots..."
restic forget \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 6 \
    --keep-yearly 2 \
    --prune

echo "[$(date -Iseconds)] Backup complete"
