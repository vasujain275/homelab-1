# RabbitMQ Global Instance (Docker)

This setup provides a **LAN-accessible** RabbitMQ message broker for development across multiple homelab projects.

---

## 1. Environment Variables

All credentials and ports are stored in `.env` for easy modification.

### `.env` Template
```env
# RabbitMQ
RABBITMQ_USER=rabbitmq
RABBITMQ_PASSWORD=StrongLocalPassword
RABBITMQ_PORT=5672
RABBITMQ_MANAGEMENT_PORT=15672
RABBITMQ_LAN_IP=192.168.x.x # Homelab laptop IP
```

---

## 2. Starting the Service

```bash
docker compose up -d
```

This will start:

* **RabbitMQ Broker** on `${RABBITMQ_LAN_IP}:${RABBITMQ_PORT}`
* **RabbitMQ Management UI** on `${RABBITMQ_LAN_IP}:${RABBITMQ_MANAGEMENT_PORT}`

---

## 3. Connecting from Projects

In your project’s configuration, use the following AMQP connection string:

```
amqp://${RABBITMQ_USER}:${RABBITMQ_PASSWORD}@${RABBITMQ_LAN_IP}:${RABBITMQ_PORT}/
```

**Example (pika Python client):**
```python
import pika

credentials = pika.PlainCredentials('${RABBITMQ_USER}', '${RABBITMQ_PASSWORD}')
parameters = pika.ConnectionParameters(
    '${RABBITMQ_LAN_IP}',
    '${RABBITMQ_PORT}',
    '/',
    credentials
)
connection = pika.BlockingConnection(parameters)
channel = connection.channel()
```

---

## 4. Using the Management UI

1. Open your browser:

   ```
   http://${RABBITMQ_LAN_IP}:${RABBITMQ_MANAGEMENT_PORT}
   ```
2. Login:

   * **Username:** `${RABBITMQ_USER}`
   * **Password:** `${RABBITMQ_PASSWORD}`

From the UI, you can monitor queues, exchanges, and connections.

---

## 5. Notes

* **LAN-only:** Services are bound to `${RABBITMQ_LAN_IP}`, preventing accidental public exposure.
* **Data Persistence:** Data is stored in the `rabbitmq_data` Docker volume to survive restarts.
