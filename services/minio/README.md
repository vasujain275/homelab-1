# MinIO Global Instance (Docker)

This setup provides a **LAN-accessible** MinIO S3-compatible object storage for development across multiple homelab projects.

---

## 1. Environment Variables

All credentials and ports are stored in `.env` for easy modification.

### `.env` Template
```env
# MinIO
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=StrongLocalPassword
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

* **MinIO API** on `${MINIO_LAN_IP}:${MINIO_PORT}`
* **MinIO Console** on `${MINIO_LAN_IP}:${MINIO_CONSOLE_PORT}`

---

## 3. Connecting from Projects

In your project’s `.env` (or S3 client config):

```env
S3_ENDPOINT=http://192.168.x.x:9000 # http://${MINIO_LAN_IP}:${MINIO_PORT}
S3_ACCESS_KEY_ID=minioadmin        # ${MINIO_ROOT_USER}
S3_SECRET_ACCESS_KEY=StrongLocalPassword # ${MINIO_ROOT_PASSWORD}
S3_BUCKET=your_bucket_name
```

---

## 4. Using the MinIO Console

1. Open your browser:

   ```
   http://${MINIO_LAN_IP}:${MINIO_CONSOLE_PORT}
   ```
2. Login:

   * **Access Key:** `${MINIO_ROOT_USER}`
   * **Secret Key:** `${MINIO_ROOT_PASSWORD}`

From the console, you can create buckets, manage files, and configure policies.

---

## 5. Notes

* **LAN-only:** Services are bound to `${MINIO_LAN_IP}`, preventing accidental public exposure.
* **Multi-project use:** Any project on your LAN can connect using the above credentials.
* **Data Persistence:** Data is stored in the `minio_data` Docker volume.
