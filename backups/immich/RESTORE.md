# Immich restore from restic + Backblaze B2

Step-by-step runbook for restoring Immich after data loss or migration.

## Prerequisites

- The `.backup.env` file with your restic password and B2 credentials
- A working Docker + Immich installation (fresh or existing)
- Enough disk space (~75 GB + overhead)

## Restore steps

### 1. Restore files from Backblaze B2

```bash
# Load secrets
source /home/vasu/homelab-1/backups/immich/.backup.env

# List available snapshots
restic snapshots
```

Output looks like:
```
ID        Date                 Host       Tags        Paths
abc12345  2026-07-17 00:00:05  homelab-1              /home/vasu/services/immich/library
                                                       /home/vasu/services/immich/upload
                                                       /home/vasu/services/immich/profile
                                                       /tmp/immich-db-2026-07-17-030000.sql.gz
def67890  2026-07-16 00:00:03  homelab-1              (same paths)
...
```

Pick the snapshot you want:

```bash
# Restore the LATEST snapshot (most common — recent data loss, SSD failure, etc.)
restic restore latest --target /tmp/immich-restore

# Or restore a SPECIFIC snapshot by ID (e.g. roll back to 2 months ago)
restic restore def67890 --target /tmp/immich-restore

# Or restore a snapshot from a specific DATE
restic restore --host homelab-1 --path "/home/vasu/services/immich" \
  $(restic snapshots --json | jq -r '.[] | select(.time | startswith("2026-05-17")) | .short_id') \
  --target /tmp/immich-restore
```

**Tip:** `restic snapshots` lists the snapshot ID (first column) and date. Use the short ID (first 8 chars, e.g. `def67890`) — restic auto-resolves it.

This creates `/tmp/immich-restore/` containing:
```
/tmp/immich-restore/
├── home/vasu/services/immich/
│   ├── library/
│   ├── upload/
│   └── profile/
└── tmp/
    └── immich-db-2026-07-17-030000.sql.gz
```

### 2. Set up Immich data directories

If Immich is already running, stop it first:
```bash
cd /home/vasu/homelab-1/setups/immich
docker compose down
```

Move the restored files into your `UPLOAD_LOCATION`:
```bash
# Assuming UPLOAD_LOCATION=/home/vasu/services/immich
rsync -a /tmp/immich-restore/home/vasu/services/immich/library/ /home/vasu/services/immich/library/
rsync -a /tmp/immich-restore/home/vasu/services/immich/upload/  /home/vasu/services/immich/upload/
rsync -a /tmp/immich-restore/home/vasu/services/immich/profile/ /home/vasu/services/immich/profile/
```

### 3. Restore the database

**Option A: Via Immich web UI (recommended for fresh installs)**

> **Note:** The onboarding integrity check will flag `thumbs/` and `encoded-video/` as empty/missing.
> This is *expected* — we intentionally skipped them in the backup. They'll be regenerated in step 4.

1. Start Immich: `docker compose up -d`
2. Open `http://192.168.1.75:2283`
3. On the onboarding/welcome screen, click **Restore from backup**
4. Immich enters maintenance mode and runs an integrity check on storage folders.
   - `library/`, `upload/`, `profile/` should show ✅ (readable, with file counts)
   - `thumbs/`, `encoded-video/`, `backups/` may show ⚠️ or "empty" — ignore, these will be regenerated
5. Click **Next** to proceed to backup selection
6. Click **Select from computer** and upload the `.sql.gz` dump file from `/tmp/immich-restore/tmp/`
7. Click **Restore**

**Option A (alternative): Via Settings (if Immich is already running)**

1. Go to **Administration → Maintenance**
2. Expand **Restore database backup**
3. Click **Select from computer** → upload the `.sql.gz` dump
4. Click **Restore**
5. Immich creates a restore point of the current DB first (safe rollback)

**Option B: Via command line (for existing or broken installs)**

```bash
# Wipe and recreate Postgres (CAUTION: destroys current DB)
docker compose down -v
sudo rm -rf /home/vasu/services/immich/postgres  # DB_DATA_LOCATION
docker compose create
docker start immich_postgres
sleep 10

# Restore the dump (atomic — all-or-nothing, auto-rollback on error)
gunzip --stdout /tmp/immich-restore/tmp/immich-db-*.sql.gz \
  | sed "s/SELECT pg_catalog.set_config('search_path', '', false);/SELECT pg_catalog.set_config('search_path', 'public, pg_catalog', true);/g" \
  | docker exec -i immich_postgres psql --dbname=immich --username=postgres --single-transaction --set ON_ERROR_STOP=on

# Start everything (remove DB_SKIP_MIGRATIONS if you used it above)
docker compose up -d
```

> **Tip:** If your compose starts the server together with the database and you can't isolate Postgres, set `DB_SKIP_MIGRATIONS=true` in `.env` before `docker compose create`. This prevents the server from running migrations that would conflict with the restore. Remove it and restart after the DB is restored.

### 4. Regenerate skipped content

After Immich is running and all assets are visible:

1. Go to **Administration → Jobs**
2. Run **Generate Thumbnails** job (select all)
3. Run **Transcode Videos** job (select all)

These will recreate `thumbs/` and `encoded-video/` from the originals. This can take hours for large libraries — let it run overnight.

### 5. Verify

- Log in to the web UI
- Check asset count matches expectation (~20,307)
- Spot-check a few albums, faces, and search
- Thumbnails should be populating as the jobs run

### 6. Cleanup

```bash
rm -rf /tmp/immich-restore
```

## Troubleshooting

**"Backup was created with a different Immich version"**
→ Normal after upgrades. Immich runs migrations automatically during restore.

**"Relation already exists" during CLI restore**
→ You need a completely fresh Postgres. Delete `DB_DATA_LOCATION` and recreate the container.

**Thumbnails not showing after restore**
→ The thumbnail generation job is still running or hasn't been started. Check Administration → Jobs.

**Missing assets after restore**
→ The DB dump and files might be out of sync. This happens if files were added between the dump and the filesystem backup. The assets exist on disk — use the "Scan external library" job to pick them up.
