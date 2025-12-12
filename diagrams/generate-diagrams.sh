#!/bin/bash
# Generate SVG and PNG files from all PlantUML diagrams
# Usage: ./generate-diagrams.sh [docker|local|auto]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

METHOD="${1:-auto}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== PlantUML Diagram Generator ===${NC}"
echo -e "${BLUE}   Centralized Monitoring Docs    ${NC}"
echo ""

shopt -s nullglob
PUML_FILES=(*.puml)
shopt -u nullglob

if [ ${#PUML_FILES[@]} -eq 0 ]; then
    echo -e "${RED}No .puml files found in $SCRIPT_DIR${NC}"
    exit 1
fi

echo "Found ${#PUML_FILES[@]} PlantUML diagram(s):"
for file in "${PUML_FILES[@]}"; do
    echo "  - $file"
done
echo ""

if [ "$METHOD" = "auto" ]; then
    if command -v plantuml &> /dev/null; then
        METHOD="local"
    elif command -v docker &> /dev/null; then
        METHOD="docker"
    else
        echo -e "${YELLOW}Warning: Neither plantuml nor docker found${NC}"
        echo "Please install one of:"
        echo "  - PlantUML: brew install plantuml"
        echo "  - Docker: brew install docker"
        exit 1
    fi
fi

echo -e "Rendering method: ${GREEN}${METHOD}${NC}"
echo ""

case "$METHOD" in
    local)
        echo "Using local plantuml installation..."
        echo ""
        echo -e "${BLUE}Generating SVG files...${NC}"
        plantuml -tsvg "${PUML_FILES[@]}"
        echo -e "${GREEN}Done${NC}"
        echo ""
        echo -e "${BLUE}Generating PNG files...${NC}"
        plantuml -tpng "${PUML_FILES[@]}"
        echo -e "${GREEN}Done${NC}"
        echo ""
        ;;
    docker)
        echo "Using Docker plantuml image..."
        echo ""
        echo -e "${BLUE}Generating SVG files...${NC}"
        docker run --rm -v "$(pwd):/data" plantuml/plantuml:latest -tsvg /data/*.puml
        echo -e "${GREEN}Done${NC}"
        echo ""
        echo -e "${BLUE}Generating PNG files...${NC}"
        docker run --rm -v "$(pwd):/data" plantuml/plantuml:latest -tpng /data/*.puml
        echo -e "${GREEN}Done${NC}"
        echo ""
        ;;
    *)
        echo -e "${RED}Unknown method: $METHOD${NC}"
        echo "Usage: $0 [docker|local|auto]"
        exit 1
        ;;
esac

echo -e "${BLUE}=== Generated Files ===${NC}"
echo ""

for puml in "${PUML_FILES[@]}"; do
    base="${puml%.puml}"
    echo -e "${GREEN}${puml}${NC}"
    if [ -f "${base}.svg" ]; then
        size=$(ls -lh "${base}.svg" | awk '{print $5}')
        echo "  - ${base}.svg (${size})"
    fi
    if [ -f "${base}.png" ]; then
        size=$(ls -lh "${base}.png" | awk '{print $5}')
        echo "  - ${base}.png (${size})"
    fi
    echo ""
done

echo -e "${GREEN}All diagrams generated successfully!${NC}"
