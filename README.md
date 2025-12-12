# Centralized Monitoring for Distributed PCA Systems

This project documents the architecture and implementation of a centralized monitoring solution for distributed PCA (Provider Connectivity Assurance) systems with remote Mobility Collector agents.

## Project Structure

- `architecture/`: High-level and detailed architecture documentation
  - `mobility-collector-analysis.md` - Remote agent architecture
  - `central-pca-integration.md` - Central PCA (AOD Deployer) integration
- `diagrams/`: PlantUML source files for system diagrams
- `setup/`: Setup and configuration guides for each component

## Key Components

### Remote Sites (Mobility Collector)
- **OTEL Exporter**: OpenTelemetry Collector for traces, metrics, logs
- **FluentD/Fluent Bit**: Log collection and forwarding
- **Prometheus**: Local metrics scraping with remote_write

### Central PCA (AOD Deployer)
- **OpenSearch/Elasticsearch**: Log storage and search
- **Thanos**: Prometheus metrics federation and long-term storage
- **Grafana**: Unified dashboards
- **Bellhop**: OpenTelemetry data processing

## Getting Started

1. Review the architecture documentation in `architecture/`
2. Generate diagrams: `cd diagrams && ./generate-diagrams.sh`
3. Follow setup guides for each component

## Diagram Generation

```bash
cd diagrams/
./generate-diagrams.sh          # Auto-detect method
./generate-diagrams.sh docker   # Use Docker
./generate-diagrams.sh local    # Use local plantuml
```

## Documentation Status

- [x] Mobility Collector Architecture Analysis
- [x] Central PCA Integration Architecture
- [x] PlantUML Diagrams (3 diagrams)
- [ ] FluentD Configuration Guide
- [ ] Thanos Setup Guide
- [ ] Security Considerations
- [ ] Troubleshooting Guide
