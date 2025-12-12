# Central PCA Integration Architecture

## Overview

The Central PCA (Provider Connectivity Assurance) solution, deployed via **AOD Deployer using Replicated KOTS**, serves as the central aggregation point for telemetry from distributed Mobility Collector instances.

**Key Configuration Files:**
- `helm/replicated/skylight-analytics-chart.yaml.in` - Replicated HelmChart values (equivalent to values.yaml)
- `helm/skylight/configs/nginx.conf` - nginx reverse proxy configuration
- `helm/replicated/config.yaml` - Replicated admin console configuration

## Central PCA Components (AOD Deployer)

### Ingress Layer

| Component | Port | Purpose |
|-----------|------|---------|
| nginx | 443 | Tenant API access |
| nginx | 2443 | Admin API access |
| nginx | 3443 | Zitadel authentication (gRPC) |

The nginx reverse proxy handles all incoming traffic and routes to appropriate backend services based on URL path. It includes:
- TLS termination with configurable certificates (cert-manager or external)
- Bearer token authentication via `/auth` subrequest to `skylight-aaa`
- mTLS client certificate validation for machine-to-machine auth

### Existing Telemetry Receivers

| Component | Protocol | Purpose | Endpoint |
|-----------|----------|---------|----------|
| OpenTelemetry Collector | OTLP/HTTP | Receives traces, metrics, logs | `/otel/` → `opentelemetry-collector:4318` |
| Bellhop | Internal | OTEL data processing | Transforms and routes telemetry |
| otel-mapping-service | Kafka | OTEL data transformation | Consumes `otel-*-in` topics |
| Kafka | TCP 9092 | Event streaming and message bus | `kafka:9092` |
| Prometheus Pushgateway | HTTP | Push gateway for batch metrics | `prometheus-gateway:9091` |

**OTEL Data Flow in Central PCA:**
```
nginx /otel/ → opentelemetry-collector:4318 → Kafka (otel-*-in topics)
                                            → otel-mapping-service → Kafka (otel-mapped-*-in)
                                            → Ignite/Druid/Elasticsearch
```

### Storage Components

| Component | Purpose | Data Type |
|-----------|---------|-----------|
| Elasticsearch | Log storage and search | Logs, events |
| Druid | Analytics OLAP database | Time-series analytics |
| Kafka | Event streaming | Real-time events, OTEL data |
| PostgreSQL | Relational data | Configuration, metadata |
| HDFS | Distributed file storage | Large datasets, Spark data |
| MinIO | S3-compatible object storage | Backups, artifacts, Druid deep storage |

### Visualization & Alerting

| Component | Purpose |
|-----------|---------|
| Grafana | Unified dashboards for metrics and logs |
| Ignite | Metric processing and alerting |
| Alert Service | Alert routing and notifications |
| Skyweather | Health monitoring dashboard |

## Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                     REMOTE SITES                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
│  │ Mobility     │  │ Mobility     │  │ Mobility     │              │
│  │ Collector 1  │  │ Collector 2  │  │ Collector N  │              │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘              │
│         │                 │                 │                       │
│         │    OTEL/HTTP    │    OTEL/HTTP    │    OTEL/HTTP         │
│         │    FluentD      │    FluentD      │    FluentD           │
│         │    remote_write │    remote_write │    remote_write      │
└─────────┼─────────────────┼─────────────────┼───────────────────────┘
          │                 │                 │
          ▼                 ▼                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     CENTRAL PCA                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    nginx Reverse Proxy                       │   │
│  │  :443 (tenant) │ :2443 (admin) │ :3443 (auth)               │   │
│  └─────────────────────────────────────────────────────────────┘   │
│         │                                                           │
│         ▼                                                           │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐    │
│  │ Bellhop OTEL    │  │ FluentD         │  │ Thanos          │    │
│  │ Collector       │  │ Aggregator      │  │ Receiver        │    │
│  │ (/otel/*)       │  │ (TCP 24224)     │  │ (remote_write)  │    │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘    │
│           │                    │                    │              │
│           ▼                    ▼                    ▼              │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    STORAGE LAYER                             │   │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐│   │
│  │  │OpenSearch │  │  Thanos   │  │   Druid   │  │   Kafka   ││   │
│  │  │  (Logs)   │  │ (Metrics) │  │(Analytics)│  │ (Events)  ││   │
│  │  └───────────┘  └───────────┘  └───────────┘  └───────────┘│   │
│  └─────────────────────────────────────────────────────────────┘   │
│           │                    │                    │              │
│           ▼                    ▼                    ▼              │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                 VISUALIZATION & ALERTING                     │   │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐               │   │
│  │  │  Grafana  │  │  Ignite   │  │  Alert    │               │   │
│  │  │           │  │           │  │  Service  │               │   │
│  │  └───────────┘  └───────────┘  └───────────┘               │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

## Recommended Technology Stack

### Logs: FluentD → OpenSearch

**Why OpenSearch over Elasticsearch?**
- Apache 2.0 license (no vendor lock-in)
- Drop-in compatible with Elasticsearch
- Active open-source community
- Built-in security features
- OpenSearch Dashboards included

**FluentD Configuration at Central PCA:**

```yaml
# Central aggregator configuration
<source>
  @type forward
  port 24224
  bind 0.0.0.0
  <security>
    self_hostname central-pca.example.com
    shared_key ${FLUENTD_SHARED_KEY}
  </security>
  <transport tls>
    cert_path /etc/fluentd/certs/server.crt
    private_key_path /etc/fluentd/certs/server.key
    ca_path /etc/fluentd/certs/ca.crt
  </transport>
</source>

<filter **>
  @type record_transformer
  <record>
    cluster ${tag_parts[1]}
    received_at ${time}
  </record>
</filter>

<match **>
  @type opensearch
  host opensearch.pca.svc.cluster.local
  port 9200
  scheme https
  ssl_verify true
  ca_file /etc/fluentd/certs/opensearch-ca.crt
  user ${OPENSEARCH_USER}
  password ${OPENSEARCH_PASSWORD}
  index_name mobility-logs-%Y.%m.%d
  <buffer>
    @type file
    path /var/log/fluentd-buffer
    flush_interval 5s
    chunk_limit_size 8MB
    total_limit_size 2GB
    retry_max_times 5
  </buffer>
</match>
```

### Metrics: Prometheus + Thanos

**Why Thanos?**
- Seamless Prometheus integration
- Global query view across sites
- Long-term storage in object storage
- High availability and deduplication
- Multi-tenancy support

**Thanos Architecture for Centralized Metrics:**

```
Remote Sites                          Central PCA
┌──────────────┐                     ┌──────────────────────────────┐
│ Prometheus   │                     │                              │
│ + Sidecar    │ ──store.api──────▶  │  Thanos Query                │
└──────────────┘                     │       │                      │
       │                             │       ▼                      │
       │ remote_write                │  Thanos Store Gateway        │
       ▼                             │       │                      │
┌──────────────┐                     │       ▼                      │
│ Thanos       │ ◀─────────────────  │  Object Storage (MinIO/S3)  │
│ Receive      │                     │                              │
└──────────────┘                     └──────────────────────────────┘
```

**Prometheus remote_write Configuration:**

```yaml
# At each Mobility Collector
remote_write:
  - url: https://central-pca.example.com/api/v1/receive
    remote_timeout: 30s
    queue_config:
      capacity: 10000
      max_shards: 50
      min_shards: 1
      max_samples_per_send: 5000
      batch_send_deadline: 30s
      min_backoff: 1s
      max_backoff: 5m
    bearer_token_file: /etc/prometheus/thanos-token
    tls_config:
      ca_file: /etc/prometheus/central-ca.crt
    write_relabel_configs:
      - source_labels: [__name__]
        regex: 'go_.*'
        action: drop  # Drop verbose Go metrics
```

### Object Storage Options: MinIO vs Apache Ozone

Thanos requires S3-compatible object storage for long-term metrics retention. The Central PCA can use either MinIO (already deployed in AOD Deployer) or Apache Ozone for this purpose. Both expose S3-compatible APIs, allowing Thanos to store and retrieve data blocks without modification. The choice between them depends on deployment scale, existing infrastructure, and operational requirements.

**Option A: MinIO**

MinIO is a lightweight, high-performance object storage system designed specifically for cloud-native environments. It is already deployed as part of the AOD Deployer stack, making it the path of least resistance for initial implementations. MinIO excels in simplicity: a single binary can serve S3-compatible storage with minimal configuration. For deployments monitoring fewer than 50 remote sites with moderate retention requirements (under 1 year of metrics), MinIO provides excellent performance with low operational overhead. The AOD Deployer's existing MinIO instance handles Druid deep storage and various backup artifacts, so extending it for Thanos storage consolidates operations onto a single object storage platform.

However, MinIO has limitations at extreme scale. While it supports distributed mode with erasure coding, managing hundreds of terabytes of metrics data across extended retention periods (multiple years) can strain MinIO clusters. Capacity planning becomes critical, and expanding storage typically requires careful coordination to maintain data integrity during scaling operations.

**Option B: Apache Ozone**

Apache Ozone is a distributed object storage system designed from the ground up for the Hadoop ecosystem. It provides S3-compatible APIs alongside native HDFS protocol support, making it particularly attractive for organizations already invested in Hadoop infrastructure. Ozone separates metadata management (via Ozone Manager and Storage Container Manager) from data storage, enabling linear scalability to exabyte-scale deployments. This architectural separation means that adding storage capacity does not create metadata bottlenecks—a common challenge with other distributed storage systems.

For Central PCA deployments expecting to monitor hundreds of remote Mobility Collectors with multi-year retention requirements, Ozone provides a more robust foundation. Its integration with the Hadoop ecosystem means that the same storage layer can serve both Thanos metrics and Spark-based analytics workloads that may already exist in the AOD Deployer environment. Ozone also supports multiple storage tiers (SSD, HDD, archival) within a single namespace, enabling cost-effective long-term retention policies.

The trade-off is operational complexity. Ozone requires deploying and managing additional components (Ozone Manager, Storage Container Manager, DataNodes), and the Hadoop ecosystem brings dependencies that may not align with purely Kubernetes-native operational models. Organizations without existing Hadoop expertise will face a steeper learning curve.

**Comparison Summary**

| Factor | MinIO | Apache Ozone |
|--------|-------|--------------|
| **Deployment Complexity** | Low - single binary or small cluster | High - multiple components (OM, SCM, DataNodes) |
| **Existing in AOD Deployer** | Yes - already deployed | No - requires new deployment |
| **Scale Ceiling** | Tens of terabytes efficiently | Exabytes with linear scaling |
| **Protocol Support** | S3 only | S3, HDFS, and native Ozone APIs |
| **Hadoop Integration** | None | Native - can serve Spark, Hive, etc. |
| **Operational Overhead** | Low | Medium-High |
| **Best For** | Small/medium deployments, <50 sites | Large deployments, 100+ sites, multi-year retention |
| **Storage Tiering** | Limited | Full support (hot/warm/cold) |

**Thanos Configuration for MinIO:**

```yaml
# thanos-storage-config.yaml
type: S3
config:
  bucket: thanos-metrics
  endpoint: pca-minio-hl.pca.svc.cluster.local:9000
  access_key: ${MINIO_ACCESS_KEY}
  secret_key: ${MINIO_SECRET_KEY}
  insecure: false
  http_config:
    idle_conn_timeout: 90s
    response_header_timeout: 2m
```

**Thanos Configuration for Apache Ozone:**

```yaml
# thanos-storage-config.yaml
type: S3
config:
  bucket: thanos-metrics
  endpoint: ozone-s3g.pca.svc.cluster.local:9878
  access_key: ${OZONE_ACCESS_KEY}
  secret_key: ${OZONE_SECRET_KEY}
  insecure: false
  http_config:
    idle_conn_timeout: 90s
    response_header_timeout: 2m
  # Ozone may require path-style access
  # depending on version and configuration
```

**Recommendation:** For most Central PCA deployments, starting with MinIO is the pragmatic choice. It requires no additional infrastructure and can be operationally validated quickly. If metrics volume grows beyond MinIO's comfortable operating range, or if the organization is already investing in Hadoop-based analytics, migrating to Apache Ozone can be planned as a future phase. The S3 API compatibility ensures that this migration is straightforward—only the Thanos storage configuration needs updating, with no changes to the remote Prometheus agents or query infrastructure.

## Required Changes to AOD Deployer

### 1. Add OpenSearch Helm Chart

```yaml
# In Chart.yaml.j2
- name: opensearch
  repository: "oci://us-docker.pkg.dev/npav-172917/helm-package"
  version: {{ components_version.uniform.opensearch }}
  condition: global.centralizedLogging.enabled
```

### 2. Add FluentD Aggregator

```yaml
# In values.yaml.in
fluentd-aggregator:
  enabled: true
  replicaCount: 2
  service:
    port: 24224
  opensearch:
    host: opensearch
    port: 9200
    index_prefix: mobility-logs
```

### 3. Add Thanos Receive Component

```yaml
# In values.yaml.in
thanos:
  receive:
    enabled: true
    replicaCount: 2
    tsdbRetention: 15d
  query:
    enabled: true
    replicaCount: 2
  storegateway:
    enabled: true
  compactor:
    enabled: true
    retentionResolutionRaw: 30d
    retentionResolution5m: 120d
    retentionResolution1h: 1y
```

### 4. nginx Route Configuration

Add routes in `nginx-config.yaml`:

```nginx
# FluentD forward (if using HTTP input)
location /fluentd/ {
    proxy_pass http://fluentd-aggregator:9880/;
    proxy_http_version 1.1;
}

# Thanos remote_write endpoint
location /api/v1/receive {
    proxy_pass http://thanos-receive:19291/api/v1/receive;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
}

# Thanos query API
location /thanos/ {
    auth_request /auth;
    proxy_pass http://thanos-query:9090/;
}
```

## Implementation Phases

### Phase 1: Log Collection (2-3 weeks)

1. Deploy FluentD/Fluent Bit to Mobility Collectors
2. Deploy FluentD Aggregator at Central PCA
3. Deploy OpenSearch cluster (if not using existing Elasticsearch)
4. Configure log forwarding and test
5. Create OpenSearch Dashboards index patterns

### Phase 2: Metrics Federation (2-3 weeks)

1. Deploy Prometheus to Mobility Collectors
2. Configure service discovery and scrape configs
3. Deploy Thanos Receive at Central PCA
4. Configure remote_write from Prometheus
5. Create Grafana datasource and dashboards

### Phase 3: Alerting Integration (1-2 weeks)

1. Configure Prometheus Alertmanager at remote sites
2. Set up alert forwarding to central Alert Service
3. Create alerting rules for cross-site correlation
4. Test and tune alert thresholds

### Phase 4: Dashboard & Runbooks (1 week)

1. Create unified Grafana dashboards
2. Document operational runbooks
3. Set up on-call escalation paths
4. Training for operations team

## Cost & Resource Estimates

### Central PCA Additional Resources

| Component | CPU | Memory | Storage |
|-----------|-----|--------|---------|
| OpenSearch (3 nodes) | 4 cores × 3 | 16GB × 3 | 500GB × 3 |
| FluentD Aggregator (2 replicas) | 1 core × 2 | 2GB × 2 | 50GB buffer |
| Thanos Receive (2 replicas) | 2 cores × 2 | 4GB × 2 | 100GB TSDB |
| Thanos Store Gateway | 1 core | 2GB | - |
| Thanos Compactor | 2 cores | 4GB | 100GB temp |

### Per Remote Site (Mobility Collector)

| Component | CPU | Memory | Storage |
|-----------|-----|--------|---------|
| FluentD/Fluent Bit | 0.5 core | 512MB | 10GB buffer |
| Prometheus | 1 core | 2GB | 50GB TSDB |

## Security Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    SECURITY LAYERS                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. NETWORK SECURITY                                            │
│     ├── TLS 1.3 for all connections                            │
│     ├── Network policies (K8s/Calico)                          │
│     └── Firewall rules (egress allowlist)                      │
│                                                                  │
│  2. AUTHENTICATION                                              │
│     ├── Bearer tokens for OTEL/Thanos                          │
│     ├── Shared keys for FluentD                                │
│     ├── mTLS for service-to-service (optional)                 │
│     └── Zitadel for user authentication                        │
│                                                                  │
│  3. AUTHORIZATION                                               │
│     ├── Tenant isolation in multi-tenant setup                 │
│     ├── RBAC for Grafana/OpenSearch access                     │
│     └── Cerbos for fine-grained policies                       │
│                                                                  │
│  4. DATA PROTECTION                                             │
│     ├── PII filtering in FluentD pipelines                     │
│     ├── Log retention policies                                 │
│     ├── Encryption at rest (OpenSearch, MinIO)                 │
│     └── Audit logging                                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Recommendations Summary

| Priority | Recommendation | Technology | Effort |
|----------|---------------|------------|--------|
| **High** | Centralize logs | FluentD + OpenSearch | Medium |
| **High** | Federate metrics | Prometheus + Thanos | Medium |
| **High** | Unified dashboards | Grafana | Low |
| Medium | Cross-site alerting | Alertmanager federation | Medium |
| Medium | Log-based alerting | OpenSearch alerting | Low |
| Low | APM/Tracing | Extend existing OTEL | Medium |
| Low | Anomaly detection | OpenSearch ML | High |

## Next Steps

1. **Review** this architecture with stakeholders
2. **Approve** the technology choices (OpenSearch, Thanos)
3. **Size** the infrastructure based on expected data volume
4. **Plan** the implementation phases
5. **Execute** Phase 1 (Log Collection) as pilot
