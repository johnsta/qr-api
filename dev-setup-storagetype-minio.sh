#!/bin/bash
# filepath: /Users/johnsta/repos/qr-api/dev-setup-storagetype-minio.sh
# Script to set up local development environment for QR Code API with MinIO storage
# This script configures the local environment to use MinIO with Docker

set -e # Exit on any error

# Set default values
CONTAINER_NAME="qrcodes"
MINIO_ENDPOINT="localhost:9000"
MINIO_ACCESS_KEY="minioadmin"
MINIO_SECRET_KEY="minioadmin"
MINIO_SECURE="false"

# Display script banner
echo "==================================================="
echo "QR Code API - MinIO Storage Setup for Local Development"
echo "==================================================="

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --container-name|-c)
      CONTAINER_NAME="$2"
      shift 2
      ;;
    --minio-endpoint|-e)
      MINIO_ENDPOINT="$2"
      shift 2
      ;;
    --access-key|-a)
      MINIO_ACCESS_KEY="$2"
      shift 2
      ;;
    --secret-key|-s)
      MINIO_SECRET_KEY="$2"
      shift 2
      ;;
    --secure|-S)
      MINIO_SECURE="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  -c, --container-name NAME  Container/bucket name (default: qrcodes)"
      echo "  -e, --minio-endpoint HOST  MinIO endpoint (default: localhost:9000)"
      echo "  -a, --access-key KEY       MinIO access key (default: minioadmin)"
      echo "  -s, --secret-key KEY       MinIO secret key (default: minioadmin)"
      echo "  -S, --secure BOOL          Use SSL/TLS for MinIO (default: false)"
      echo "  -h, --help                 Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Check if Docker is running
echo "Checking if Docker is running..."
if ! docker info > /dev/null 2>&1; then
  echo "⚠️ Docker seems to be not running. Please start Docker first."
  exit 1
fi
echo "✓ Docker is running"

# Check if docker-compose file exists
echo "Checking for docker-compose.yml..."
if [ ! -f "docker-compose.yml" ]; then
  echo "⚠️ docker-compose.yml not found. Please make sure you're in the project root directory."
  exit 1
fi
echo "✓ docker-compose.yml found"

# Create .env file for local development
echo "Creating/updating .env file with MinIO configuration..."
if [ -f .env ]; then
  echo "✓ Using existing .env file"
elif [ -f .env.example ]; then
  cp .env.example .env
  echo "✓ Created .env file from .env.example"
else
  touch .env
  echo "✓ Created new .env file"
fi

# Update .env file with MinIO configuration
# Remove existing storage-related settings
sed -i '' '/STORAGE_TYPE/d' .env 2>/dev/null
sed -i '' '/CONTAINER_NAME/d' .env 2>/dev/null
sed -i '' '/MINIO_ENDPOINT/d' .env 2>/dev/null
sed -i '' '/MINIO_ACCESS_KEY/d' .env 2>/dev/null
sed -i '' '/MINIO_SECRET_KEY/d' .env 2>/dev/null
sed -i '' '/MINIO_SECURE/d' .env 2>/dev/null
sed -i '' '/AZURE_STORAGE_ACCOUNT_NAME/d' .env 2>/dev/null
sed -i '' '/AZURE_STORAGE_CONNECTION_STRING/d' .env 2>/dev/null
sed -i '' '/AZURE_TENANT_ID/d' .env 2>/dev/null
sed -i '' '/AZURE_CLIENT_ID/d' .env 2>/dev/null
sed -i '' '/AZURE_CLIENT_SECRET/d' .env 2>/dev/null

# Add new MinIO settings
cat >> .env << EOL
# MinIO Storage configuration (updated by dev-setup-storagetype-minio.sh)
STORAGE_TYPE=minio
CONTAINER_NAME=$CONTAINER_NAME
MINIO_ENDPOINT=$MINIO_ENDPOINT
MINIO_ACCESS_KEY=$MINIO_ACCESS_KEY
MINIO_SECRET_KEY=$MINIO_SECRET_KEY
MINIO_SECURE=$MINIO_SECURE
EOL

echo "✓ Updated .env file with MinIO configuration"

# Check if the API service and MinIO are running in Docker
echo "Checking MinIO container status..."
MINIO_RUNNING=$(docker ps --format '{{.Names}}' | grep -E '(^|_)minio(_|$)')
API_RUNNING=$(docker ps --format '{{.Names}}' | grep -E '(^|_)api(_|$)')

if [ -n "$MINIO_RUNNING" ]; then
  echo "✓ MinIO container is running"
else
  echo "⚠️ MinIO container is not running"
  SHOULD_START=true
fi

if [ -n "$API_RUNNING" ]; then
  echo "✓ API container is running"
else
  echo "⚠️ API container is not running"
  SHOULD_START=true
fi

if [ "$SHOULD_START" = "true" ]; then
  echo ""
  read -p "Would you like to start the Docker containers now? (y/N): " START_CONTAINERS
  if [[ "$START_CONTAINERS" =~ ^[Yy]$ ]]; then
    echo "Starting Docker containers..."
    docker compose up -d
    echo "✓ Docker containers started"
  fi
fi

echo ""
echo "=============================================================="
echo "✅ Setup complete! Your QR Code API is now configured to use"
echo "   MinIO for local development."
echo ""
echo "   Container/Bucket: $CONTAINER_NAME"
echo "   MinIO Endpoint:   $MINIO_ENDPOINT"
echo "   MinIO Console:    http://localhost:9001"
echo ""
echo "   To start the API and MinIO (if not using Docker Compose):"
echo "   npm start"
echo ""
echo "   To access the MinIO Console:"
echo "   - URL: http://localhost:9001"
echo "   - Username: $MINIO_ACCESS_KEY"
echo "   - Password: $MINIO_SECRET_KEY"
echo "=============================================================="
