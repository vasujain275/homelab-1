# MySQL + Adminer Global Instance (Docker)

This setup provides a **LAN-accessible** MySQL database and Adminer web UI for development across multiple homelab projects.

---

## 1. Environment Variables

All credentials and ports are stored in `.env` for easy modification.

### `.env` Template
```env
# MySQL
MYSQL_ROOT_PASSWORD=StrongRootPassword
MYSQL_USER=mysql
MYSQL_PASSWORD=StrongLocalPassword
MYSQL_PORT=3306
MYSQL_LAN_IP=192.168.x.x  # Homelab laptop IP

# Adminer
ADMINER_PORT=8306
```

---

## 2. Starting the Services

```bash
docker compose up -d
```

This will start:

* **MySQL** on `${MYSQL_LAN_IP}:${MYSQL_PORT}`
* **Adminer** on `${MYSQL_LAN_IP}:${ADMINER_PORT}`

---

## 3. Connecting from Projects

In your project's `.env` (or DB config):

```env
MYSQL_HOST=192.168.x.x        # ${MYSQL_LAN_IP}
MYSQL_PORT=3306               # ${MYSQL_PORT}
MYSQL_USER=mysql              # ${MYSQL_USER}
MYSQL_PASSWORD=StrongLocalPassword  # ${MYSQL_PASSWORD}
MYSQL_DATABASE=your_database_name
```

---

## 4. Accessing MySQL CLI

```bash
docker exec -it mysql_global mysql -u ${MYSQL_USER} -p
```

Or as root:

```bash
docker exec -it mysql_global mysql -u root -p
```

Enter the password when prompted.

---

## 5. Using Adminer

1. Open your browser:

   ```
   http://${MYSQL_LAN_IP}:${ADMINER_PORT}
   ```
2. Login:

   * **System:** MySQL
   * **Server:** `mysql_db`
   * **Username:** `${MYSQL_USER}` (or `root`)
   * **Password:** `${MYSQL_PASSWORD}` (or `${MYSQL_ROOT_PASSWORD}` for root)
   * **Database:** leave empty or specify your database name

---

## 6. Creating Databases

You can create databases via Adminer UI or using the MySQL CLI:

```bash
docker exec -it mysql_global mysql -u root -p -e "CREATE DATABASE your_database_name;"
```

---

## 7. Notes

* **Backups:** Use `mysqldump` periodically to avoid data loss.
* **LAN-only:** Services are bound to `${MYSQL_LAN_IP}`, preventing accidental public exposure.
* **Multi-project use:** Any project on your LAN can connect using the above credentials.
* **Authentication:** Uses `mysql_native_password` for better compatibility with older clients.
