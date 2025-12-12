# Central PCA Integration Architecture

## Overview

The Central PCA (Provider Connectivity Assurance) solution, deployed via **AOD Deployer using Replicated KOTS**, serves as the central aggregation point for telemetry from distributed Mobility Collector instances.

**Key Configuration Files:**
- `helm/replicated/skylight-analytics-chart.yaml.in` - Replicated HelmChart values
- `helm/skylight/configs/nginx.conf` - nginx reverse proxy configuration
- `helm/replicated/config.yaml` - Replicated admin console configuration

## Central PCA Components (AOD Deployer)

### Ingress Layer

| Component | Port | Purpose |
|-----------|------|--------|
| nginx | 443 | Tenant API access |
| nginx | 2443 | Admin API access |
| nginx | 3443 | Zitadel authentication (gRPC) |

### Existing Telemetry Receivers

| Component | Protocol | Purpose | Endpoint |
|-----------|----------|---------|----------|
| OpenTelemetry Collector | OTLP/HTTP | Receives traces, metrics, logs | `/otel/` -> `opentelemetry-collector:4318` |
| Bellhop | Internal | OTEL data processing | Transforms and routes telemetry |
| otel-mapping-service | Kafka | OTEL data transformation | Consumes `otel-*-in` topics |
| Kafka | TCP 9092 | Event streaming and message bus | `kafka:9092` |
| Prometheus Pushgateway | HTTP | Push gateway for batch metrics | `prometheus-gateway:9091` |

**OTEL Data Flow in Central PCA:**
```
nginx /otel/ -> opentelemetry-collector:4318 -> Kafka (otel-*-in topics)
                                             -> otel-mapping-service -> Kafka (otel-mapped-*-in)
                                             -> Ignite/Druid/Elasticsearch
```

### Storage Components

| Component | Purpose | Data Type |
|-----------|---------|----------|
| Elasticsearch | Log storage and search | Logs, events |
| Druid | Analytics OLAP database | Time-series analytics |
| Kafka | Event streaming | Real-time events, OTEL data |
| PostgreSQL | Relational data | Configuration, metadata |
| HDFS | Distributed file storage | Large datasets, Spark data |
| MinIO | S3-compatible object storage | Backups, artifacts, Druid deep storage |

### Visualization & Alerting

| Component | Purpose |
|-----------|--------|
| Grafana | Unified dashboards for metrics and logs |
| Ignite | Metric processing and alerting |
| Alert Service | Alert routing and notifications |
| Skyweather | Health monitoring dashboard |

## Recommended Technology Stack

### Logs: FluentD + OpenSearch

**Why OpenSearch?**
- Apache 2.0 license (no vendor lock-in)
- Drop-in compatible with Elasticsearch
- Active open-source community
- Built-in security features

### Metrics: Prometheus + Thanos

**Why Thanos?**
- Seamless Prometheus integration
- Global query view across sites
- Long-term storage in object storage
- High availability and deduplication

## Implementation Phases

### Phase 1: Log Collection (2-3 weeks)
1. Deploy FluentD to Mobility Collectors
2. Deploy FluentD Aggregator at Central PCA
3. Deploy OpenSearch cluster
4. Configure and test log forwarding

### Phase 2: Metrics Federation (2-3 weeks)
1. Deploy Prometheus to Mobility Collectors
2. Deploy Thanos Receive at Central PCA
3. Configure remote_write
4. Create Grafana dashboards

### Phase 3: Alerting Integration (1-2 weeks)
1. Configure Alertmanager at remote sites
2. Set up alert forwarding
3. Create alerting rules

## Resource Estimates

### Central PCA Additions

| Component | CPU | Memory | Storage |
|-----------|-----|--------|--------|
| OpenSearch (3 nodes) | 4 cores x 3 | 16GB x 3 | 500GB x 3 |
| FluentD Aggregator | 1 core x 2 | 2GB x 2 | 50GB |
| Thanos Receive | 2 cores x 2 | 4GB x 2 | 100GB |

### Per Remote Site

| Component | CPU | Memory | Storage |
|-----------|-----|--------|--------|
| FluentD/Fluent Bit | 0.5 core | 512MB | 10GB |
| Prometheus | 1 core | 2GB | 50GB |
