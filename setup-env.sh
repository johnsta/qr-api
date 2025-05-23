#!/bin/bash
# filepath: /Users/johnsta/repos/qr-api/setup-env.sh
set -e

echo "QR Code Generator API - Environment Setup"
echo "========================================"

# Check if .env file exists
if [ -f .env ]; then
  echo "An .env file already exists."
  read -p "Do you want to replace it with a fresh copy from .env.example? (y/N): " answer
  
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    cp .env.example .env
    echo "Created new .env file from .env.example"
  else
    echo "Keeping existing .env file"
  fi
else
  # Create .env file from example
  cp .env.example .env
  echo "Created .env file from .env.example"
fi

echo ""
echo "You can now edit the .env file to configure your environment:"
echo "- For local development with MinIO: use default settings"
echo "- For Azure: set STORAGE_TYPE=azure and configure Azure settings"
echo ""
echo "To edit your .env file:"
echo "nano .env  # or use your preferred editor"
