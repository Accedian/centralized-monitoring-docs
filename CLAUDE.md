# Centralized Monitoring Documentation Project

## Project Overview

This repository contains architecture documentation, PlantUML diagrams, and setup guides for implementing centralized monitoring across distributed PCA (Provider Connectivity Assurance) systems.

**Key Systems:**
- **Mobility Collector** - Remote agents deployed at customer sites
- **AOD Deployer** - Central PCA solution deployed via Replicated KOTS

## Repository Structure

```
centralized-monitoring-docs/
├── architecture/           # Architecture documentation
│   ├── overview.md         # High-level system overview
│   ├── mobility-collector-analysis.md  # Remote agent architecture
│   └── central-pca-integration.md      # Central PCA integration
├── diagrams/               # PlantUML source files
│   ├── generate-diagrams.sh  # Script to generate SVG/PNG
│   ├── *.puml              # PlantUML diagram sources
│   └── *.svg, *.png        # Generated outputs (gitignored)
└── setup/                  # Setup and configuration guides
```

## Development Guidelines

### Documentation Style

1. **Markdown formatting**: Use proper headings, tables, and code blocks
2. **Tables**: Use Markdown tables for component listings and comparisons
3. **Code examples**: Include YAML/JSON configurations where relevant
4. **ASCII diagrams**: For inline flow diagrams in Markdown files

### PlantUML Diagrams

1. **File naming**: Use descriptive kebab-case names (e.g., `centralized-monitoring-flow.puml`)
2. **Colors**: Use consistent color scheme:
   - Remote/FM components: `#E8F5E9` (green)
   - Central/PM components: `#E3F2FD` (blue)
   - Storage: `#FFF3E0` (orange)
   - Recommended additions: `#C8E6C9` (light green)
3. **Title and footer**: Always include a descriptive title
4. **Notes**: Use notes to explain complex configurations

### Diagram Generation

```bash
cd diagrams/
./generate-diagrams.sh          # Auto-detect method
./generate-diagrams.sh docker   # Use Docker
./generate-diagrams.sh local    # Use local plantuml (brew install plantuml)
```

## Related Projects

| Project | Repository | Purpose |
|---------|------------|---------|
| AOD Deployer | `Accedian/aod-deployer` | Central PCA Helm charts (Replicated) |
| Mobility Collector | `Accedian/mobility-collector` | Remote agent Helm charts |

## Key Configuration Files (Reference)

### AOD Deployer
- `helm/replicated/skylight-analytics-chart.yaml.in` - Replicated HelmChart values
- `helm/skylight/configs/nginx.conf` - nginx reverse proxy configuration
- `helm/replicated/config.yaml` - Replicated admin console configuration

### Mobility Collector
- `helm/values.yaml` - Default umbrella chart values
- `helm/subcharts/<component>/` - Individual service charts

## Technology Stack

### Recommended for Centralized Monitoring

| Category | Technology | Purpose |
|----------|------------|---------|
| Logs | FluentD + OpenSearch | Log collection, aggregation, search |
| Metrics | Prometheus + Thanos | Metrics scraping, federation, long-term storage |
| Visualization | Grafana | Unified dashboards |
| Telemetry | OpenTelemetry | Traces, metrics, logs via OTLP |

### Existing in Central PCA

| Component | Endpoint | Purpose |
|-----------|----------|---------|
| Bellhop OTEL Collector | `/otel/` → `:4318` | Receives OTLP telemetry |
| otel-mapping-service | Kafka topics | Transforms OTEL data |
| Elasticsearch | Internal | Log storage (existing) |
| Kafka | `:9092` | Event streaming |
| Grafana | `/grafana/` | Visualization |

## Commands

```bash
# Generate diagrams
cd diagrams && ./generate-diagrams.sh

# View generated files
ls -la diagrams/*.svg diagrams/*.png

# Push to GitHub
git add -A && git commit -m "docs: update architecture" && git push
```

## Agent Notes

- Documentation is synced to GitHub: `Accedian/centralized-monitoring-docs`
- Notion page: "Centralized monitoring" under K8s PCA central Architecture
- When updating diagrams, regenerate SVG/PNG files before committing
- Keep architecture docs in sync with actual AOD Deployer and Mobility Collector configurations
