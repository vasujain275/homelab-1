# Immich backup — restic → Backblaze B2

Daily automated backup of Immich originals and database to Backblaze B2.
Runs at 3 AM via systemd timer, keeps 7 daily + 4 weekly + 6 monthly + 2 yearly snapshots.

## What gets backed up

| Path | Size | What |
|---|---|---|
| `library/` | ~71 GB | Originals imported via external library feature |
| `upload/` | ~4.1 GB | Originals uploaded via browser/mobile/CLI |
| `profile/` | ~8 KB | User avatar images |
| DB dump | ~few MB | PostgreSQL dump (gzipped), fresh per run |

**Total: ~75 GB**

## What is skipped (regenerable)

| Path | Size | How to regenerate |
|---|---|---|
| `thumbs/` | ~4.6 GB | Administration → Jobs → Generate Thumbnails (all) |
| `encoded-video/` | ~16 GB | Administration → Jobs → Transcode Videos (all) |
| `backups/` | ~2 GB | Immich auto DB dumps — redundant, this script does its own dump |
| `postgres/` | ~589 MB | Raw pgdata — dump is safer and smaller |

## Cost (INR)

Backblaze B2: **$6.95/TB/month** (≈ ₹0.59/GB/month at ₹85/USD).
Uploads free. Downloads free up to 3× average stored.

| | Storage | Monthly | Yearly |
|---|---|---|---|
| Today | 75 GB | ~₹44 | — |
| After 1 year | ~185 GB | ~₹109 | ~₹800–1,000 |

Full restore is always free (well within the 3× free egress allowance).

## Security

All data is **encrypted client-side** before it leaves your server. restic uses:
- **AES-256-GCM** per chunk
- Key derived from `RESTIC_PASSWORD` via scrypt (high iteration count)
- **TLS** in transit to B2

Backblaze B2 never sees your photos — they only store encrypted blobs with random hex filenames. The `RESTIC_PASSWORD` is the sole decryption key. If lost, the backup is **unrecoverable**.

## Prerequisites

### On the homelab server

```bash
sudo apt install restic
```

### In Backblaze B2 web console

If you don't have a Backblaze B2 account yet, [sign up here](https://www.backblaze.com/b2/sign-up).

#### Step 1: Create a bucket

1. Go to [**Buckets**](https://secure.backblaze.com/b2_buckets.htm) in the B2 web console
2. Click **Create a Bucket**
3. Name: `vj-immich-backup` (or any name you prefer — update `RESTIC_REPOSITORY` to match)
4. Set to **Private** (files are only accessible with your keys)
5. Choose a region:
   - `us-east-005` (Sacramento, CA) — good latency from India, standard pricing
   - `eu-central-003` (Amsterdam) — if you prefer EU servers
   - Region affects the endpoint URL in `.backup.env`. Stick with one.
6. Leave encryption as default (AES-256, server-side)
7. Click **Create a Bucket**

#### Step 2: Create an application key

> ⚠️ **Important:** Do NOT use the master application key with restic's S3 backend — it's not supported and won't work.

1. Go to [**App Keys**](https://secure.backblaze.com/app_keys.htm)
2. Click **Add a New Application Key**
3. Name: `immich-restic` (or any name)
4. **Key Type:** `S3 Compatible` (NOT "Master Application Key")
5. **Access:** restrict to the bucket you just created:
   - Select the `vj-immich-backup` bucket
   - Permissions needed: **Read, Write, List, Delete** (restic needs all four)
6. Click **Create Application Key**
7. **Copy the `keyID` and `applicationKey` immediately** — they're shown only once.
   - `keyID` → goes in `.backup.env` as `AWS_ACCESS_KEY_ID`
   - `applicationKey` → goes in `.backup.env` as `AWS_SECRET_ACCESS_KEY`

> If you lose the key, create a new one and update `.backup.env`. Old keys can be revoked.

#### Step 3: Set lifecycle rule (critical for cost)

Without this, restic's deleted blobs stay as hidden versions in B2 and you **keep getting billed** for them.

1. Go to [**Buckets**](https://secure.backblaze.com/b2_buckets.htm) → click your `vj-immich-backup` bucket
2. Click **Lifecycle Settings**
3. Under **File Versions**, set:
   - "Keep only the **last** version"
4. Click **Save Lifecycle Settings**

This ensures `restic forget --prune` actually frees storage. Without it, your B2 bill will grow even as restic deletes old snapshots.

#### Verify

You can test the bucket is reachable using the AWS CLI (same S3 API restic uses):

```bash
# One-time: install aws CLI
sudo apt install awscli

# Test (use the actual keyID and applicationKey)
AWS_ACCESS_KEY_ID=your_key_id \
AWS_SECRET_ACCESS_KEY=your_app_key \
aws s3 ls s3://vj-immich-backup/ --endpoint-url https://s3.us-east-005.backblazeb2.com --region us-east-005
```

If it returns without errors, the bucket is set up correctly. Now proceed to [Setup](#setup) below.

## Setup

### 1. Configure secrets

```bash
cd /home/vasu/homelab-1/backups/immich
cp .backup.env.example .backup.env
chmod 600 .backup.env
```

Edit `.backup.env` and fill in:
- `AWS_ACCESS_KEY_ID` → the `keyID` from B2
- `AWS_SECRET_ACCESS_KEY` → the `applicationKey` from B2
- `RESTIC_PASSWORD` → generate with `openssl rand -base64 32`
- `RESTIC_REPOSITORY` → replace region/bucket name if different

### 2. Initialize the restic repository

```bash
source .backup.env
restic init
```

### 3. Test a manual run

```bash
./backup.sh
```

First run uploads all 75 GB. Subsequent runs only upload changes (dedup + incremental).

### 4. Install systemd timer

```bash
sudo cp immich-backup.service immich-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now immich-backup.timer
```

Verify:
```bash
systemctl status immich-backup.timer
systemctl list-timers | grep immich
```

## Monitoring

Check last run status:
```bash
systemctl status immich-backup.service
```

View logs:
```bash
journalctl -u immich-backup.service --since "2 days ago"
```

List snapshots in the repo:
```bash
source /home/vasu/homelab-1/backups/immich/.backup.env
restic snapshots
```

Monthly integrity check (add a separate systemd timer):
```bash
restic check
```

## Restore

See [RESTORE.md](RESTORE.md) for the full step-by-step runbook.

Quick version:
1. Restore files from restic: `restic restore latest --target /restore`
2. Move `library/`, `upload/`, `profile/` into your `UPLOAD_LOCATION`
3. Move the `.sql.gz` dump somewhere accessible
4. Start Immich, use onboarding → "Restore from backup" → upload the dump
5. Run "Generate Thumbnails" + "Transcode Videos" jobs

## Files in this directory

| File | Purpose |
|---|---|
| `backup.sh` | The backup script (run by systemd timer) |
| `.backup.env.example` | Template for B2 credentials and restic config |
| `.backup.env` | Actual secrets (gitignored, chmod 600) |
| `immich-backup.service` | systemd service unit |
| `immich-backup.timer` | systemd timer unit (daily at 3 AM) |
| `README.md` | This file |
| `RESTORE.md` | Detailed restore runbook |
