# Valkey (Redis) Global Instance (Docker)

This setup provides a **LAN-accessible** Valkey (Redis) instance for development across multiple homelab projects.

---

## 1. Environment Variables

All credentials and ports are stored in `.env` for easy modification.

### `.env` Template
```env
REDIS_PORT=6379
REDIS_LAN_IP=192.168.x.x     # Homelab laptop IP
REDIS_PASSWORD=StrongLocalPassword
```

2. Starting the Service
```bash
docker compose up -d
```
This will start Valkey on ${REDIS_LAN_IP}:${REDIS_PORT}.

3. Connecting from Projects
In your project’s .env (or config):

```env
REDIS_HOST=192.168.x.x       # ${REDIS_LAN_IP}
REDIS_PORT=6379              # ${REDIS_PORT}
REDIS_PASSWORD=StrongLocalPassword  # ${REDIS_PASSWORD}
```

4. Using the Redis CLI
If you have Redis CLI installed locally:

```bash
redis-cli -h ${REDIS_LAN_IP} -p ${REDIS_PORT} -a ${REDIS_PASSWORD}
```

Or directly inside the container:

```bash
docker exec -it valkey_global redis-cli -a ${REDIS_PASSWORD}
```

5. Notes

- Password-protected: Instance requires ${REDIS_PASSWORD} for all connections.

- Persistence: Data is stored with appendonly yes for durability.

- LAN-only: Bound to ${REDIS_LAN_IP}, preventing accidental public exposure.

- Multi-project use: Any project on your LAN can connect using the above credentials.

- Backup: The dump.rdb and appendonly.aof files are stored in the redis_data volume.
