# filepath: /Users/johnsta/repos/qr-api/infra/scripts/deploy.sh
#!/usr/bin/env bash
set -euo pipefail

# ----------------------
# Variables & Arguments
# ----------------------
RESOURCE_GROUP="qr-code-api-rg"
LOCATION="eastus"
BICEP_FILE="../bicep/main.bicep"
PARAMETERS_FILE="../bicep/parameters/dev.parameters.json"
API_DIR="../../"
ENV="dev"

# Navigate to this script's folder
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Parse -e (environment) and -l (location)
while getopts "e:l:" opt; do
  case $opt in
    e) ENV=$OPTARG ;;
    l) LOCATION=$OPTARG ;;
    *) echo "Usage: $0 [-e environment] [-l location]" >&2; exit 1 ;;
  esac
done

# Adjust for prod vs. dev
if [[ "$ENV" == "prod" ]]; then
  PARAMETERS_FILE="../bicep/parameters/prod.parameters.json"
  RESOURCE_GROUP="qr-code-api-rg-prod"
else
  PARAMETERS_FILE="../bicep/parameters/dev.parameters.json"
  RESOURCE_GROUP="qr-code-api-rg-dev"
fi

# --------------
# Azure Login & RG
# --------------
echo "👉 Logging in to Azure..."
# az login

echo "👉 Ensuring resource group $RESOURCE_GROUP exists in $LOCATION..."
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION"

# -------------------
# Bicep What-If & Deploy
# -------------------
echo "🔍 Previewing template changes..."
az deployment group what-if \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$BICEP_FILE" \
  --parameters @"$PARAMETERS_FILE"

echo "🚀 Deploying Bicep template..."
DEPLOY_OUTPUT=$(az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$BICEP_FILE" \
  --parameters @"$PARAMETERS_FILE" \
  --output json)

# Extract outputs
APP_SERVICE_NAME=$(echo "$DEPLOY_OUTPUT" | jq -r '.properties.outputs.appServiceName.value')
STORAGE_ACCOUNT_NAME=$(echo "$DEPLOY_OUTPUT" | jq -r '.properties.outputs.storageAccountName.value')
CONTAINER_NAME="qrcodes"

echo "✅ Deployed resources:"
echo "  - App Service: $APP_SERVICE_NAME"
echo "  - Storage Account: $STORAGE_ACCOUNT_NAME"

# ----------------
# Storage Container
# ----------------
echo "👉 Creating storage container '$CONTAINER_NAME'..."
az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --auth-mode login \
  --public-access blob

# -----------------
# Configure App Settings
# -----------------
echo "⚙️ Configuring app settings..."
az webapp config appsettings set \
  --name "$APP_SERVICE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --settings \
  "STORAGE_TYPE=azure" \
  "AZURE_STORAGE_ACCOUNT_NAME=$STORAGE_ACCOUNT_NAME" \
  "CONTAINER_NAME=$CONTAINER_NAME" \
  "WEBSITES_PORT=8000" \
  "NODE_ENV=production" \
  "NODE_VERSION=~18" \
  "SCM_DO_BUILD_DURING_DEPLOYMENT=true" \

# --------------
# Deploy Code
# --------------
echo "📦 Packaging and deploying code..."
cd "$API_DIR"

# Prepare zip file for deployment
echo "📦 Creating deployment package..."
rm -f qr-api-deploy.zip
# Include only needed files for Node.js app
zip -r qr-api-deploy.zip \
  app.js \
  package*.json \
  startup.sh \
  node_modules

echo "📤 Deploying code to App Service..."
az webapp deployment source config-zip \
  --resource-group "$RESOURCE_GROUP" \
  --name "$APP_SERVICE_NAME" \
  --src "qr-api-deploy.zip"

echo "💻 Restarting web app..."
az webapp restart \
  --name "$APP_SERVICE_NAME" \
  --resource-group "$RESOURCE_GROUP"

# -----------------
# Output Information
# -----------------
echo -e "\n🎯 Deployment complete!"
echo "App URL: https://$APP_SERVICE_NAME.azurewebsites.net"
echo "Test the API: https://$APP_SERVICE_NAME.azurewebsites.net/health"
