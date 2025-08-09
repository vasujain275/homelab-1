# PostgreSQL + pgAdmin Global Instance (Docker)

This setup provides a **LAN-accessible** PostgreSQL database and pgAdmin web UI for development across multiple homelab projects.

---

## 1. Environment Variables

All credentials and ports are stored in `.env` for easy modification.

### `.env` Template
```env
# PostgreSQL
POSTGRES_USER=postgres
POSTGRES_PASSWORD=StrongLocalPassword
POSTGRES_PORT=5432
POSTGRES_LAN_IP=192.168.x.x  # Homelab laptop IP

# pgAdmin
PGADMIN_EMAIL=admin@example.com
PGADMIN_PASSWORD=AnotherStrongPassword
PGADMIN_PORT=8432
````

---

## 2. Starting the Services

```bash
docker compose up -d
```

This will start:

* **PostgreSQL** on `${POSTGRES_LAN_IP}:${POSTGRES_PORT}`
* **pgAdmin** on `${POSTGRES_LAN_IP}:${PGADMIN_PORT}`

---

## 3. Connecting from Projects

In your project’s `.env` (or DB config):

```env
PGHOST=192.168.x.x        # ${POSTGRES_LAN_IP}
PGPORT=5432               # ${POSTGRES_PORT}
PGUSER=postgres           # ${POSTGRES_USER}
PGPASSWORD=StrongLocalPassword  # ${POSTGRES_PASSWORD}
PGDATABASE=your_database_name
```

---

## 4. Accessing `psql` CLI

```bash
docker exec -it postgres_global psql -U ${POSTGRES_USER} -W ${PGDATABASE}
```

Replace `${PGDATABASE}` with your database name (default: `postgres`).

---

## 5. Using pgAdmin

1. Open your browser:

   ```
   http://${POSTGRES_LAN_IP}:${PGADMIN_PORT}
   ```
2. Login:

   * **Email:** `${PGADMIN_EMAIL}`
   * **Password:** `${PGADMIN_PASSWORD}`
3. Add a new server:

   * **General → Name:** any friendly name
   * **Connection → Host name/address:** `postgres_db`
   * **Port:** `5432`
   * **Maintenance database:** `${POSTGRES_USER}`
   * **Username:** `${POSTGRES_USER}`
   * **Password:** `${POSTGRES_PASSWORD}`

---

## 6. Notes

* **Backups:** Use `pg_dump` or `pg_dumpall` periodically to avoid data loss.
* **LAN-only:** Services are bound to `${POSTGRES_LAN_IP}`, preventing accidental public exposure.
* **Multi-project use:** Any project on your LAN can connect using the above credentials.
