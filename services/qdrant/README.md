# Qdrant Global Instance (Docker)

This setup provides a **LAN-accessible** Qdrant vector database for development across multiple homelab projects.

---

## 1. Environment Variables

All credentials and ports are stored in `.env` for easy modification.

### `.env` Template
```env
# Qdrant
QDRANT_PORT=6333
QDRANT_HTTP_PORT=6334
QDRANT_LAN_IP=192.168.x.x # Homelab laptop IP
QDRANT_API_KEY=StrongLocalPassword
```

---

## 2. Starting the Service

```bash
docker compose up -d
```

This will start:

* **Qdrant gRPC API** on `${QDRANT_LAN_IP}:${QDRANT_PORT}`
* **Qdrant REST API & Web UI** on `${QDRANT_LAN_IP}:${QDRANT_HTTP_PORT}`

---

## 3. Connecting from Projects

In your project’s client configuration:

**Python Client Example:**
```python
import qdrant_client

client = qdrant_client.QdrantClient(
    host="${QDRANT_LAN_IP}",
    port=${QDRANT_PORT},
    # or for REST API:
    # url=f"http://${QDRANT_LAN_IP}:${QDRANT_HTTP_PORT}", 
    api_key="${QDRANT_API_KEY}",
)
```

**cURL Example (REST):**
```bash
curl -X GET "http://${QDRANT_LAN_IP}:${QDRANT_HTTP_PORT}/collections" \
  -H "api-key: ${QDRANT_API_KEY}"
```

---

## 4. Using the Web UI

1. Open your browser:

   ```
   http://${QDRANT_LAN_IP}:${QDRANT_HTTP_PORT}/dashboard
   ```

---

## 5. Notes

* **LAN-only:** Services are bound to `${QDRANT_LAN_IP}`, preventing accidental public exposure.
* **API Key:** The `QDRANT_API_KEY` is required for all client connections.
* **Data Persistence:** Data is stored in the `qdrant_data` Docker volume.

```