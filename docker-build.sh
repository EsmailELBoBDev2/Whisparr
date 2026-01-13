#!/bin/bash
set -e

echo "=========================================="
echo "  Whisparr Custom Build Script"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
BUILD_ONLY=false
RUN_AFTER_BUILD=false
FORCE_REBUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --build-only)
            BUILD_ONLY=true
            shift
            ;;
        --run)
            RUN_AFTER_BUILD=true
            shift
            ;;
        --force)
            FORCE_REBUILD=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --build-only    Only build the image, don't run"
            echo "  --run           Run the container after building"
            echo "  --force         Force rebuild without cache"
            echo "  --help          Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

echo -e "${YELLOW}Building Whisparr from source...${NC}"
echo "This may take several minutes on first build."
echo ""

# Build arguments
BUILD_ARGS=""
if [ "$FORCE_REBUILD" = true ]; then
    BUILD_ARGS="--no-cache"
fi

# Build the image
echo -e "${GREEN}Step 1: Building Docker image...${NC}"
docker build $BUILD_ARGS -t whisparr:custom .

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}=========================================="
    echo "  Build completed successfully!"
    echo "==========================================${NC}"
    echo ""
    echo "Image: whisparr:custom"
    echo ""
    echo "To run the container:"
    echo "  docker run -d \\"
    echo "    --name whisparr-custom \\"
    echo "    -p 6969:6969 \\"
    echo "    -v ./config:/config \\"
    echo "    -v /path/to/media:/media \\"
    echo "    whisparr:custom"
    echo ""
    echo "Or use docker-compose:"
    echo "  docker-compose up -d"
else
    echo -e "${RED}Build failed!${NC}"
    exit 1
fi

# Run if requested
if [ "$RUN_AFTER_BUILD" = true ]; then
    echo -e "${GREEN}Step 2: Running container...${NC}"
    
    # Stop existing container if running
    docker stop whisparr-custom 2>/dev/null || true
    docker rm whisparr-custom 2>/dev/null || true
    
    # Create config directory
    mkdir -p ./config
    
    # Run the container
    docker run -d \
        --name whisparr-custom \
        -p 6969:6969 \
        -v "$(pwd)/config:/config" \
        whisparr:custom
    
    echo ""
    echo -e "${GREEN}Container started!${NC}"
    echo "Access Whisparr at: http://localhost:6969"
fi
