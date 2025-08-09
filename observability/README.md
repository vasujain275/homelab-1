# Homelab Observability Stack

This directory contains a complete, pre-configured observability stack for a homelab environment. It provides a centralized system for collecting, storing, and visualizing metrics, logs, and traces from all your applications and services.

---

## 1. Components

The stack is composed of several key open-source tools, all running in Docker containers:

*   **Grafana**: The central dashboard for visualizing all your data. You will use Grafana to view metrics from Prometheus and logs from Loki, and to correlate them.
*   **Prometheus**: A time-series database that scrapes and stores metrics from your applications and the infrastructure they run on.
*   **Loki**: A log aggregation system that collects and stores logs from all your services.
*   **Promtail**: The agent that discovers container logs on the Docker host and forwards them to Loki.
*   **Jaeger**: A distributed tracing system used to monitor and troubleshoot transactions in complex microservice environments.
*   **OpenTelemetry Collector**: A vendor-agnostic agent for receiving, processing, and exporting telemetry data (metrics, logs, and traces). It is the single entry point for all your application instrumentation.

## 2. How It Works

1.  **Your Application**, instrumented with an OpenTelemetry SDK, sends traces, metrics, and logs to the **OpenTelemetry Collector**.
2.  The **Collector** processes this data:
    *   Traces are sent to **Jaeger**.
    *   Metrics are exposed on a `/metrics` endpoint.
    *   Logs are forwarded to **Loki**.
3.  **Prometheus** scrapes metrics from the **Collector** and other configured targets (like services that expose a Prometheus endpoint).
4.  **Promtail** scrapes logs directly from Docker container output and sends them to **Loki**.
5.  **Grafana** connects to Prometheus and Loki as data sources, allowing you to query, visualize, and create dashboards for all your telemetry data in one place.

## 3. Setup & Configuration

### Environment Variables (`.env`)

Create a `.env` file in this directory by copying the `.env.sample`. All exposed ports and the LAN IP are configured here.

```env
# Observability Stack
OBSERVABILITY_LAN_IP=192.168.x.x # Your homelab laptop IP

# Ports for UI access
GRAFANA_PORT=3000
PROMETHEUS_PORT=9090
JAEGER_UI_PORT=16686

# Ports for data ingestion
LOKI_PORT=3100
OTEL_COLLECTOR_GRPC_PORT=4317
OTEL_COLLECTOR_HTTP_PORT=4318
```

### Adding Prometheus Targets

To collect metrics from a new service, add a new scrape configuration to `prometheus/config/prometheus.yml`.

### Instrumenting Applications

To send data from your applications, configure your OpenTelemetry SDK to export to the Collector's OTLP endpoint:
*   `http://${OBSERVABILITY_LAN_IP}:${OTEL_COLLECTOR_HTTP_PORT}`

## 4. Getting Started

1.  **Start the stack:**
    ```bash
    docker compose up -d
    ```

2.  **Configure Grafana (First-time only):**
    *   Navigate to `http://${OBSERVABILITY_LAN_IP}:${GRAFANA_PORT}`.
    *   Login with `admin` / `admin` (and change the password).
    *   Add the **Prometheus** data source with the URL `http://prometheus:9090`.
    *   Add the **Loki** data source with the URL `http://loki:3100`.

3.  **Explore your data:**
    *   Use the **Explore** tab in Grafana to view metrics and logs.
    *   View traces in the **Jaeger UI** at `http://${OBSERVABILITY_LAN_IP}:${JAEGER_UI_PORT}`.
