# Backups

Automated backup configurations for homelab services.

Each subdirectory contains the backup script, environment template, systemd units, and documentation for a specific service.

## Services

| Service | Tool | Destination | Schedule |
|---|---|---|---|
| [Immich](immich/) | restic | Backblaze B2 | Daily, 3 AM |

## Conventions

- `.backup.env` — actual secrets (gitignored, never committed)
- `.backup.env.example` — template with placeholder values
- `backup.sh` — the backup script
- `*.service` / `*.timer` — systemd units for scheduling
- `README.md` — setup, costs, configuration
- `RESTORE.md` — step-by-step disaster recovery runbook
