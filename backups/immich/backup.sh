#!/bin/bash
# Immich backup to Backblaze B2 via restic
#
# What gets backed up:
#   - library/       originals (external library imports)
#   - upload/        originals (mobile/browser uploads)
#   - profile/       user avatar images
#   - DB dump        PostgreSQL dump (gzipped), fresh per run
#
# What is skipped (regenerable):
#   - thumbs/         → regenerate: Administration > Jobs > Generate Thumbnails
#   - encoded-video/  → regenerate: Administration > Jobs > Transcode Videos
#   - backups/        → Immich auto DB dumps (redundant)
#   - postgres/       → raw pgdata (dump is safer and smaller)
#
# Consistency: immich-server is stopped before the DB dump and restarted after.
# This prevents lock contention and ensures DB + filesystem are in sync.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.backup.env"
IMMICH_DIR="/home/vasu/homelab-1/setups/immich"
DUMP_FILE="/tmp/immich-db-$(date +%F-%H%M%S).sql.gz"
START_TIME=$(date +%s)

# ── Helpers ──
log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
err()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2; }
die()  { err "$@"; exit 1; }
elapsed() {
    local now sec min
    now=$(date +%s)
    sec=$((now - START_TIME))
    min=$((sec / 60))
    sec=$((sec % 60))
    echo "${min}m ${sec}s"
}

# ── Ensure server is restarted even if script fails ──
cleanup() {
    local exit_code=$?
    if docker ps -a --format '{{.Names}}' | grep -q '^immich_server$'; then
        if ! docker inspect immich_server --format '{{.State.Running}}' 2>/dev/null | grep -q true; then
            log "Restarting immich-server (cleanup handler)..."
            docker start immich_server >/dev/null 2>&1 || true
        fi
    fi
    if [[ -f "$DUMP_FILE" ]]; then
        rm -f "$DUMP_FILE"
    fi
    log "Backup finished. Total time: $(elapsed). Exit code: $exit_code"
}
trap cleanup EXIT

# ── 1. Load and verify secrets ──
log "=== Step 1/6: Loading credentials ==="
if [[ ! -f "$ENV_FILE" ]]; then
    die "$ENV_FILE not found. Copy .backup.env.example and fill in secrets."
fi
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

for var in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY RESTIC_PASSWORD RESTIC_REPOSITORY; do
    if [[ -z "${!var:-}" ]]; then
        die "$var is not set in $ENV_FILE"
    fi
done
log "Credentials loaded OK (repo: $RESTIC_REPOSITORY)"

# ── 2. Stop immich-server for consistency ──
log "=== Step 2/6: Stopping immich-server ==="
if docker inspect immich_server --format '{{.State.Running}}' 2>/dev/null | grep -q true; then
    log "immich-server is running — stopping..."
    cd "$IMMICH_DIR"
    docker compose stop immich-server 2>&1 | while IFS= read -r line; do log "  docker: $line"; done
    log "immich-server stopped OK"
else
    log "immich-server already stopped (or not found) — proceeding"
fi

# ── 3. Dump database ──
log "=== Step 3/6: Dumping PostgreSQL database ==="
log "Running pg_dump on immich_postgres container..."

# Check postgres is running
if ! docker inspect immich_postgres --format '{{.State.Running}}' 2>/dev/null | grep -q true; then
    die "immich_postgres container is not running. Cannot dump database."
fi

# Run dump with progress visibility
docker exec immich_postgres \
    pg_dump --clean --if-exists --dbname=immich --username=postgres \
    2>&1 | gzip > "$DUMP_FILE"

DUMP_SIZE=$(du -h "$DUMP_FILE" | cut -f1)
if [[ ! -s "$DUMP_FILE" ]]; then
    die "Database dump file is empty (0 bytes). Aborting."
fi
log "Database dumped: $DUMP_SIZE"

# ── 4. Backup files to B2 ──
log "=== Step 4/6: Uploading to Backblaze B2 ==="
log "Scanning /home/vasu/services/immich/{library,upload,profile} + $DUMP_FILE"
log "This may take a while on first run (~75 GB). Subsequent runs are incremental."

SNAPSHOT_COUNT_BEFORE=$(restic snapshots --json 2>/dev/null | grep -c '"short_id"' || echo "0")

restic backup \
    /home/vasu/services/immich/library \
    /home/vasu/services/immich/upload \
    /home/vasu/services/immich/profile \
    "$DUMP_FILE" 2>&1 | while IFS= read -r line; do
    # Show restic output but skip noisy "unchanged" lines unless they're summary
    if [[ "$line" =~ (snapshot|error|warning|fatal|processed|duration|E[Tt][Aa]|added) ]]; then
        log "  restic: $line"
    fi
done

SNAPSHOT_COUNT_AFTER=$(restic snapshots --json 2>/dev/null | grep -c '"short_id"' || echo "0")
log "Upload complete. Snapshots: $SNAPSHOT_COUNT_BEFORE -> $SNAPSHOT_COUNT_AFTER"

# ── 5. Restart immich-server ──
log "=== Step 5/6: Restarting immich-server ==="
cd "$IMMICH_DIR"
docker compose start immich-server 2>&1 | while IFS= read -r line; do log "  docker: $line"; done
log "immich-server started OK"

# ── 6. Prune old snapshots ──
log "=== Step 6/6: Pruning old snapshots ==="
log "Retention: 7 daily, 4 weekly, 6 monthly, 2 yearly"
restic forget \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 6 \
    --keep-yearly 2 \
    --prune 2>&1 | while IFS= read -r line; do
    if [[ -n "$line" ]]; then
        log "  restic: $line"
    fi
done

# ── Done ──
log "=== Backup complete ==="
log "Total time: $(elapsed)"
log "DB dump: $DUMP_SIZE"
log "Repo: $RESTIC_REPOSITORY"
log "Snapshots: $(restic snapshots --json 2>/dev/null | grep -c '"short_id"' || echo "0")"
