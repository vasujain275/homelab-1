# MinIO Global Instance (Docker)

This setup provides a **LAN-accessible** MinIO S3-compatible object storage for development across multiple homelab projects.

---

## 1. Environment Variables

All credentials and ports are stored in `.env` for easy modification.

⚠️ **Important**

* Quote passwords if they contain special characters (for example `#`, `!`, `$`).

### `.env` Template

```env
# MinIO
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD="StrongLocalPassword"
MINIO_PORT=9000
MINIO_CONSOLE_PORT=9001
MINIO_LAN_IP=192.168.x.x # Homelab laptop IP
```

---

## 2. Starting the Service

```bash
docker compose up -d
```

This will start:

* **MinIO API** on `http://${MINIO_LAN_IP}:${MINIO_PORT}`
* **MinIO Console** on `http://${MINIO_LAN_IP}:${MINIO_CONSOLE_PORT}`

---

## 3. Connecting from Projects

In your project’s `.env` (or S3 client configuration):

```env
S3_ENDPOINT=http://192.168.x.x:9000   # http://${MINIO_LAN_IP}:${MINIO_PORT}
S3_ACCESS_KEY_ID=minioadmin          # ${MINIO_ROOT_USER}
S3_SECRET_ACCESS_KEY=StrongLocalPassword # ${MINIO_ROOT_PASSWORD}
S3_BUCKET=your_bucket_name
```

> ⚠️ **Recommendation:**
> Use **non-root credentials** for applications. Root credentials should be used only for administration.

---

## 4. Using the MinIO Console

1. Open your browser:

   ```
   http://${MINIO_LAN_IP}:${MINIO_CONSOLE_PORT}
   ```
2. Login:

   * **Access Key:** `${MINIO_ROOT_USER}`
   * **Secret Key:** `${MINIO_ROOT_PASSWORD}`

From the console, you can:

* Create and delete buckets
* Upload, download, and manage objects

> ℹ️ **Note (Community Edition)**
> The MinIO Community Edition console is **object-browser only**.
> User, policy, and IAM management are **not available in the web UI**.

---

## 5. Client Access & Administration (Arch Linux)

This section applies to **client machines** (not the MinIO host) running **Arch Linux**.

### 5.1 Install MinIO Client (`mc`)

```bash
sudo pacman -S minio-client
```

Verify:

```bash
mc --version
```

---

### 5.2 Configure MinIO Alias

Add the global MinIO instance as an alias:

```bash
mc alias set minio-global \
  http://${MINIO_LAN_IP}:${MINIO_PORT} \
  ${MINIO_ROOT_USER} \
  "${MINIO_ROOT_PASSWORD}"
```

Example:

```bash
mc alias set minio-global http://192.168.1.75:9000 minioadmin "StrongLocalPassword"
```

Aliases are stored locally at:

```
~/.mc/config.json
```

---

### 5.3 Verify Connection

List buckets:

```bash
mc ls minio-global
```

Check server info:

```bash
mc admin info minio-global
```

---

### 5.4 Bucket Management

Create a bucket:

```bash
mc mb minio-global/my-bucket
```

List buckets:

```bash
mc ls minio-global
```

---

### 5.5 User & Policy Management (Community Edition)

All IAM management must be done using `mc`.

Create a user:

```bash
mc admin user add minio-global appuser apppassword
```

Attach a policy:

```bash
mc admin policy attach minio-global readwrite --user appuser
```

Use these credentials in applications:

```env
S3_ACCESS_KEY_ID=appuser
S3_SECRET_ACCESS_KEY=apppassword
```

---

## 6. Resetting MinIO (Full Wipe)

To completely reset MinIO (delete all buckets, users, and config):

```bash
docker compose down
docker volume rm minio_data
docker compose up -d
```

⚠️ This permanently deletes all stored data.

---

## 7. Notes

* **LAN-only:** Services are bound to `${MINIO_LAN_IP}`, preventing accidental public exposure.
* **Multi-project use:** Any project on your LAN can connect using S3-compatible clients.
* **Data Persistence:** All data and configuration are stored in the `minio_data` Docker volume.
* **Best Practice:** Create per-application users and avoid using the root credentials in apps.
