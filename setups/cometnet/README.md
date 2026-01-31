# CometNet Homelab Deployment

This is a self-hosted CometNet instance configured for homelab deployment behind CGNAT using Cloudflare Tunnels with Caddy reverse proxy.

## What is CometNet?

CometNet is a decentralized P2P network integrated into Comet that automatically shares torrent **metadata** (not files) between instances. When your instance discovers a torrent, its metadata is propagated to other nodes - and you receive metadata discovered by others.

**Key Features:**
- Peer-to-peer with no central server
- Cryptographically signed contributions
- Reputation system to filter bad actors
- Trust Pools for private communities

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│ HOMELAB (Behind CGNAT)                                              │
│                                                                     │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────────┐  │
│  │  PostgreSQL │◄───│    Comet    │◄───│    Caddy Reverse Proxy  │  │
│  │  :5432      │    │  :8000 HTTP │    │    :8766 (external)     │  │
│  │  (internal) │    │  :8765 WS   │    │                         │  │
│  └─────────────┘    └─────────────┘    │  /cometnet/ws → :8765   │  │
│                                        │  /*          → :8000   │  │
│                                        └────────────┬────────────┘  │
│                                                     │               │
│  ┌──────────────────────────────────────────────────┴─────────────┐ │
│  │                  Cloudflare Tunnel (cloudflared)               │ │
│  │                                                                │ │
│  │   comet.vasujain.me → http://192.168.1.75:8766                 │ │
│  │                                                                │ │
│  └────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼ (outbound tunnel)
                      ┌──────────────────┐
                      │  Cloudflare Edge │
                      │                  │
                      │  comet.vasujain.me (HTTPS/WSS)
                      └──────────────────┘
                                │
                                ▼
                      ┌──────────────────┐
                      │  CometNet Peers  │
                      │  (P2P Network)   │
                      └──────────────────┘
```

**Traffic Flow:**
1. External request hits `comet.vasujain.me` (Cloudflare)
2. Cloudflare Tunnel routes to `192.168.1.75:8766` (Caddy)
3. Caddy routes based on path:
   - `/cometnet/ws` → Comet WebSocket (:8765)
   - Everything else → Comet HTTP API (:8000)

## Prerequisites

- Docker and Docker Compose
- Cloudflare account with a domain
- Cloudflare Tunnel (cloudflared) installed and running
- Server with at least 2GB available RAM

## Directory Structure

```
/path/to/this/folder/            # This folder (config files)
├── docker-compose.yml           # Container orchestration
├── Caddyfile                    # Caddy reverse proxy config
├── .env.example                 # Template (commit-safe)
├── .env                         # Actual secrets (DO NOT COMMIT)
└── README.md                    # This file

/home/vasu/services/cometnet/    # Data directory (persistent storage)
├── comet/                       # Comet app data + CometNet keys
├── postgres/                    # PostgreSQL database
└── caddy/                       # Caddy data and config
    ├── data/
    └── config/
```

## Deployment Steps

### Step 1: Configure Cloudflare Tunnel

In **Cloudflare Zero Trust Dashboard** → **Networks** → **Tunnels** → **[Your Tunnel]** → **Public Hostnames**:

Add **one** hostname entry (Caddy handles path-based routing):

| Subdomain | Domain | Type | URL |
|-----------|--------|------|-----|
| `comet` | `vasujain.me` | HTTP | `192.168.1.75:8766` |

> **Note:** Cloudflare automatically handles WebSocket upgrades. Caddy routes `/cometnet/ws` to the WebSocket port internally.

### Step 2: Create Data Directory

```bash
sudo mkdir -p /home/vasu/services/cometnet/{comet,postgres,caddy/data,caddy/config}
sudo chown -R $(id -u):$(id -g) /home/vasu/services/cometnet
```

### Step 3: Configure Environment

```bash
# Copy the example file
cp .env.example .env

# Edit with your settings
nano .env
```

**Required changes in `.env`:**

| Variable | What to set |
|----------|-------------|
| `POSTGRES_PASSWORD` | Strong random password |
| `ADMIN_DASHBOARD_PASSWORD` | Password for Comet admin UI |
| `COMETNET_ADVERTISE_URL` | `wss://comet.vasujain.me/cometnet/ws` (already set) |
| `COMETNET_BOOTSTRAP_NODES` | Get from Comet Discord or leave empty |

### Step 4: Deploy

```bash
# Start the stack
docker compose up -d

# Check logs
docker compose logs -f

# Verify all containers are healthy
docker compose ps
```

### Step 5: Verify CometNet

1. **Check container health:**
   ```bash
   docker compose ps
   ```
   All three containers (comet-caddy, comet, comet-postgres) should be healthy.

2. **Check CometNet startup:**
   ```bash
   docker compose logs comet | grep -i cometnet
   ```
   Look for: `CometNet started - Node ID: abc123...`

3. **Test HTTP endpoint:**
   ```bash
   curl https://comet.vasujain.me/health
   ```
   Should return: `{"status":"ok"}`

4. **Test WebSocket endpoint:**
   ```bash
   curl -I https://comet.vasujain.me/cometnet/ws
   ```
   Should return `405 Method Not Allowed` (expected - it's a WebSocket endpoint)

5. **Access Admin Dashboard:**
   - Go to `https://comet.vasujain.me/admin`
   - Login with `ADMIN_DASHBOARD_PASSWORD`
   - Check CometNet tab for peer connections

## Configuration Reference

### Ports

| Port | Service | Purpose |
|------|---------|---------|
| 8766 | Caddy | External entry point (Cloudflare Tunnel) |
| 8000 | Comet | HTTP API (internal, via Caddy) |
| 8765 | Comet | CometNet WebSocket (internal, via Caddy) |
| 5432 | PostgreSQL | Database (internal only) |

### Caddy Routing

| Path | Destination | Protocol |
|------|-------------|----------|
| `/cometnet/ws` | `comet:8765` | WebSocket |
| `/*` (everything else) | `comet:8000` | HTTP |

### Configuration Categories

The `.env.example` file contains **all** available options organized into sections:

| Section | Description |
|---------|-------------|
| Database Credentials | PostgreSQL connection settings |
| Stremio Addon | Addon ID and name |
| FastAPI Server | Workers, Gunicorn settings |
| Dashboard | Admin password, metrics API |
| Cache Settings | TTL for metadata, torrents, debrid |
| Background Scraper | Auto-scraping configuration |
| Anime Mapping | AniList/MAL integration |
| Networking & Proxy | Global proxy, rate limiting |
| Jackett/Prowlarr | Indexer manager configuration |
| Scrapers | All supported scrapers (Zilean, Torrentio, etc.) |
| Debrid Proxy | Stream proxying settings |
| Content Filtering | Adult content, language detection |
| HTTP Cache | Cloudflare cache headers |
| CometNet Core | P2P network settings |
| CometNet Advanced | Gossip, transport, reputation tuning |
| Trust Pools | Private communities |
| Private Networks | Isolated network mode |

### Key CometNet Variables

| Variable | Description |
|----------|-------------|
| `COMETNET_ENABLED` | Must be `True` for integrated mode |
| `FASTAPI_WORKERS` | Must be `1` for integrated mode |
| `COMETNET_ADVERTISE_URL` | `wss://comet.vasujain.me/cometnet/ws` |
| `COMETNET_BOOTSTRAP_NODES` | Entry points to discover peers |
| `COMETNET_UPNP_ENABLED` | Set `False` if behind CGNAT |
| `COMETNET_MAX_PEERS` | Max connections (lower = less resources) |
| `COMETNET_CONTRIBUTION_MODE` | `full`, `consumer`, `source`, or `leech` |

### Contribution Modes

| Mode | Shares Own | Receives | Repropagates | Use Case |
|------|------------|----------|--------------|----------|
| `full` | Yes | Yes | Yes | Default, full participation |
| `consumer` | No | Yes | Yes | Passive node |
| `source` | Yes | No | No | Dedicated scraper |
| `leech` | No | Yes | No | Selfish mode |

## Troubleshooting

### "Reachability check failed"

CometNet verifies your advertise URL is accessible on startup.

**Solutions:**
1. Verify Cloudflare Tunnel is running and route is correct
2. Check Caddy logs: `docker compose logs caddy`
3. Increase retry settings in `.env`:
   ```env
   COMETNET_REACHABILITY_RETRIES=15
   COMETNET_REACHABILITY_RETRY_DELAY=20
   ```
4. For testing only: `COMETNET_SKIP_REACHABILITY_CHECK=True`

### Caddy not starting

1. Check Caddyfile syntax: `docker compose logs caddy`
2. Ensure port 8766 is not in use: `ss -tlnp | grep 8766`

### No peers connecting

1. Check bootstrap nodes are configured correctly
2. Verify WebSocket URL is accessible externally
3. Check Comet Discord for correct bootstrap URLs

### High memory usage

Reduce resource consumption:
```env
COMETNET_MAX_PEERS=15
COMETNET_GOSSIP_FANOUT=2
```

### Database connection errors

1. Ensure PostgreSQL is healthy: `docker compose ps`
2. Check credentials match between services
3. Wait for PostgreSQL to fully start (healthcheck)

## Data Management

### Backup

```bash
# Stop containers first for consistent backup
docker compose stop

# Backup data directory
tar -czvf cometnet-backup-$(date +%Y%m%d).tar.gz /home/vasu/services/cometnet/

# Restart
docker compose start
```

### Move data to different drive

1. Stop containers: `docker compose stop`
2. Move data: `mv /home/vasu/services/cometnet /new/path/cometnet`
3. Update `docker-compose.yml` volume paths
4. Start containers: `docker compose up -d`

### Reset CometNet identity

To get a new Node ID (loses reputation):
```bash
docker compose stop
rm -rf /home/vasu/services/cometnet/comet/cometnet/
docker compose up -d
```

## Useful Commands

```bash
# View live logs (all containers)
docker compose logs -f

# View specific container logs
docker compose logs -f caddy
docker compose logs -f comet
docker compose logs -f postgres

# Restart specific service
docker compose restart caddy
docker compose restart comet

# Check container stats
docker stats comet-caddy comet comet-postgres

# Enter Comet container
docker compose exec comet bash

# PostgreSQL shell
docker compose exec postgres psql -U comet -d comet

# Test local endpoints
docker compose exec caddy wget -qO- http://comet:8000/health
```

## Resources

- [Comet GitHub](https://github.com/g0ldyy/comet)
- [Comet Discord](https://discord.com/invite/UJEqpT42nb)
- [CometNet Documentation](https://github.com/g0ldyy/comet/blob/main/COMETNET.md)
- [Caddy Documentation](https://caddyserver.com/docs/)

## Notes

- **Single subdomain** - Caddy handles path-based routing, so only one Cloudflare Tunnel route needed
- **UPnP will not work** behind CGNAT - Cloudflare Tunnel is the correct solution
- **Single worker required** - CometNet integrated mode needs `FASTAPI_WORKERS=1`
- **Bootstrap nodes** - Ask on Comet Discord for current public bootstrap URLs
- **Resource usage** - This setup uses ~400-700MB RAM total (Caddy + Comet + PostgreSQL)
