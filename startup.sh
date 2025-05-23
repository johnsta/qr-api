# filepath: /Users/johnsta/repos/qr-api/startup.sh
#!/usr/bin/env bash
set -euo pipefail

echo ">>> Starting startup.sh in $(pwd)"
echo ">>> Contents:"
ls -alh

echo ">>> $(node --version) | $(npm --version)"

# Ensure package.json is present
if [[ ! -f package.json ]]; then
  echo "ERROR: package.json not found in $(pwd)"
  exit 1
fi

echo ">>> Installing dependencies..."
npm install --production

echo ">>> Verifying key modules..."
node - <<'NODECODE'
try {
  const express = require('express');
  const qrcode = require('qrcode');
  console.log(`express: ${require('express/package.json').version}`);
  console.log(`qrcode:  ${require('qrcode/package.json').version}`);
} catch (error) {
  console.error(`Error loading modules: ${error.message}`);
  process.exit(1);
}
NODECODE

# Check for environment configuration
if [[ -n "${WEBSITES_PORT:-}" ]]; then
  # Running in Azure App Service - use environment variables from App Service
  echo ">>> Running in Azure App Service - using App Service environment variables"
else
  # Local development
  if [[ -f .env ]]; then
    echo ">>> Found .env file for local development"
  else
    echo ">>> Note: No .env file found for local development. Using environment variables only."
  fi
fi

# Determine port (Azure passes it via WEBSITES_PORT)
PORT="${WEBSITES_PORT:-8000}"
echo ">>> Launching app on 0.0.0.0:${PORT}"
exec node app.js
