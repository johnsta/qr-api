#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------
# Configuration
# ---------------------------------------------------
RESOURCE_GROUP=${RESOURCE_GROUP:-qrcode-api-rg}
LOCATION=${LOCATION:-southeastasia}
PLAN_NAME=${PLAN_NAME:-qrcode-api-plan}
APP_NAME=${APP_NAME:-qrcode-api-app}
STORAGE_ACCOUNT_NAME=${STORAGE_ACCOUNT_NAME:-qrcodeapistoragedev}
CONTAINER_NAME=${CONTAINER_NAME:-qrcodes}

# ---------------------------------------------------
# 1. Create Resource Group
# ---------------------------------------------------
echo "➤ Creating resource group: $RESOURCE_GROUP in $LOCATION..."
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION"

# ---------------------------------------------------
# 2. Create Storage Account (disable local auth)
# ---------------------------------------------------
echo "➤ Creating storage account: $STORAGE_ACCOUNT_NAME (with shared-key disabled)…"
az storage account create \
  --name "$STORAGE_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --allow-shared-key-access false

# ---------------------------------------------------
# 3. Create App Service Plan (Linux)
# ---------------------------------------------------
echo "➤ Creating App Service plan: $PLAN_NAME..."
az appservice plan create \
  --name "$PLAN_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --is-linux \
  --sku B1

# ---------------------------------------------------
# 4. Create Web App (Node.js)
# ---------------------------------------------------
echo "➤ Creating Web App: $APP_NAME (Node.js 22 LTS)..."
az webapp create \
  --resource-group "$RESOURCE_GROUP" \
  --plan "$PLAN_NAME" \
  --name "$APP_NAME" \
  --runtime "NODE|22-lts"

# ---------------------------------------------------
# 5. Assign System-Assigned Managed Identity
# ---------------------------------------------------
echo "➤ Enabling system-assigned managed identity on Web App…"
MSI_PRINCIPAL_ID=$(az webapp identity assign \
  --resource-group "$RESOURCE_GROUP" \
  --name "$APP_NAME" \
  --query principalId -o tsv)
echo "  → Principal ID: $MSI_PRINCIPAL_ID"

# 5a. Wait for the service principal to exist in AAD
echo "➤ Waiting for service principal to propagate to AAD…"
for i in {1..12}; do
  if az ad sp show --id "$MSI_PRINCIPAL_ID" &> /dev/null; then
    echo "  → Service principal is now available."
    break
  else
    echo "  → Not yet available, sleeping 5s…"
    sleep 5
  fi
done

# ---------------------------------------------------
# 6. Grant Storage Blob Data Contributor Role
# ---------------------------------------------------
echo "➤ Granting Storage Blob Data Contributor role…"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT_NAME"
az role assignment create \
  --assignee "$MSI_PRINCIPAL_ID" \
  --role "Storage Blob Data Contributor" \
  --scope "$SCOPE"

# ---------------------------------------------------
# 7. Configure App Settings
# ---------------------------------------------------
echo "➤ Setting AZURE_STORAGE_ACCOUNT_NAME in Web App..."
az webapp config appsettings set \
  --resource-group "$RESOURCE_GROUP" \
  --name "$APP_NAME" \
  --settings \
  "STORAGE_TYPE=azure" \
  "AZURE_STORAGE_ACCOUNT_NAME=$STORAGE_ACCOUNT_NAME" \
  "CONTAINER_NAME=$CONTAINER_NAME" \
  "PORT=8000" \
  "WEBSITES_PORT=8000" \
  "NODE_ENV=production" \
  "SCM_DO_BUILD_DURING_DEPLOYMENT=true" \
  "AZURE_STORAGE_USE_MANAGED_IDENTITY=true"

# ---------------------------------------------------
# 8. Package & Deploy
# ---------------------------------------------------
echo "➤ Packaging application into deployment.zip..."
zip -r deployment.zip . \
  -x "node_modules/*" \
  -x ".git/*" \
  -x ".deployment" \
  -x "startup.sh" \
  -x "deployment.zip"

echo "➤ Deploying to Azure App Service..."
az webapp deploy \
  --resource-group "$RESOURCE_GROUP" \
  --name "$APP_NAME" \
  --src-path deployment.zip \
  --type zip

echo "✅ Deployment complete! Your app is live at https://$APP_NAME.azurewebsites.net"
