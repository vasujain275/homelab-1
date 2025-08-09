# LangFuse LLM Observability (Docker)

This setup provides a **LAN-accessible** LangFuse server for LLM application observability, analytics, and prompt management.

It is configured to use the global PostgreSQL instance for its database.

---

## 1. Prerequisites

**This service will not start without completing these steps.**

1.  **PostgreSQL Service:** Ensure the global PostgreSQL service (from `services/postgresql`) is running.

2.  **Create LangFuse Database:** Manually create the `langfuse` database inside your PostgreSQL instance. You can do this by connecting with any `psql` client or by running the following command from the `/services/postgresql` directory:

    ```bash
    # Replace postgres with your actual POSTGRES_USER if you changed it
    docker exec -it postgres_global psql -U postgres -c "CREATE DATABASE langfuse;"
    ```

---

## 2. Environment Variables

Create a `.env` file in this directory by copying the `.env.sample` and fill in the values.

*   `DATABASE_URL`: Must point to your global PostgreSQL instance and the `langfuse` database you created.
*   `LANGFUSE_SECRET`: Provide a long, random string for security.
*   `LANGFUSE_PUBLIC_KEY` & `LANGFUSE_SECRET_KEY`: Leave these blank on the first start.

---

## 3. Starting the Service

1.  **Start the server:**
    ```bash
    docker compose up -d
    ```

2.  **Get API Keys:** On the first run, the server will generate your API keys. View the container's logs to get them:
    ```bash
    docker logs langfuse_global
    ```
    Look for lines containing `LANGFUSE_PUBLIC_KEY` and `LANGFUSE_SECRET_KEY`.

3.  **Update `.env` file:** Copy the generated keys into your `.env` file. This makes them easily accessible for configuring your applications and prevents them from being regenerated.

4.  **Restart the service:**
    ```bash
    docker compose restart
    ```

---

## 4. Accessing LangFuse

*   **UI:** `http://${LANGFUSE_LAN_IP}:${LANGFUSE_PORT}`
*   **API Endpoint:** `http://${LANGFUSE_LAN_IP}:${LANGFUSE_PORT}`

When instrumenting your LLM application with the LangFuse SDK, you will need the public key, secret key, and the API endpoint.
