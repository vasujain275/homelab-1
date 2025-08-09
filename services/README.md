# Homelab Services

This directory contains various backend services that can be run on a homelab server and accessed by other projects on the local network. Each service is defined in its own directory and runs in a Docker container.

## Quick Reference

| Service | Description | Access / Connection |
| :--- | :--- | :--- |
| **LangFuse** | LLM observability and analytics. | UI: `http://<LAN_IP>:<LANGFUSE_PORT>` <br> API: `http://<LAN_IP>:<LANGFUSE_PORT>` |
| **MinIO** | S3-compatible object storage. | Console: `http://<LAN_IP>:<MINIO_CONSOLE_PORT>` <br> API: `http://<LAN_IP>:<MINIO_PORT>` |
| **PostgreSQL** | Relational database server. | `psql -h <LAN_IP> -p <POSTGRES_PORT> -U <USER>` <br> pgAdmin: `http://<LAN_IP>:<PGADMIN_PORT>` |
| **Qdrant** | Vector database for AI applications. | UI: `http://<LAN_IP>:<QDRANT_HTTP_PORT>/dashboard` <br> gRPC: `<LAN_IP>:<QDRANT_PORT>` |
| **RabbitMQ** | Message broker. | Management: `http://<LAN_IP>:<RABBITMQ_MANAGEMENT_PORT>` <br> AMQP: `amqp://<USER>:<PASS>@<LAN_IP>:<RABBITMQ_PORT>` |
| **Redis** | In-memory data store. | `redis-cli -h <LAN_IP> -p <REDIS_PORT> -a <PASS>` |

---

## How to Use

1.  **Navigate** to the directory of the service you want to start (e.g., `cd services/postgresql`).
2.  **Configure**: Copy the `.env.sample` file to `.env` and fill in the required values, such as your homelab's LAN IP address and any desired passwords.
3.  **Start**: Run `docker compose up -d` to start the service in the background.
4.  **Connect**: Use the connection details from the table above to access the service from your other projects.

For detailed setup instructions, prerequisites, and configuration options for each service, please refer to the `README.md` file within its respective directory.
