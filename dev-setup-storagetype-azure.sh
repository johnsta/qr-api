#!/bin/bash
# Script to set up local development environment for QR Code API with Azure Storage
# This script creates Azure resources and configures the local environment 
# to use Azure Storage with passwordless authentication (DefaultAzureCredential)

set -e # Exit on any error

# Set default values
RESOURCE_GROUP="qr-api-resources"
LOCATION="southeastasia"
STORAGE_ACCOUNT="qrcodeapistorage"
CONTAINER_NAME="qrcodes"
IDENTITY_NAME="qr-api-identity"
SERVICE_PRINCIPAL_NAME="qr-api-local-dev"

# Display script banner
echo "==================================================="
echo "QR Code API - Azure Storage Setup with Managed Identity"
echo "==================================================="

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --resource-group|-g)
      RESOURCE_GROUP="$2"
      shift 2
      ;;
    --location|-l)
      LOCATION="$2"
      shift 2
      ;;
    --storage-account|-s)
      STORAGE_ACCOUNT="$2"
      shift 2
      ;;
    --container-name|-c)
      CONTAINER_NAME="$2"
      shift 2
      ;;
    --identity-name|-i)
      IDENTITY_NAME="$2"
      shift 2
      ;;
    --service-principal-name|-p)
      SERVICE_PRINCIPAL_NAME="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  -g, --resource-group NAME    Resource group name (default: qr-api-resources)"
      echo "  -l, --location LOCATION      Azure location (default: eastus)"
      echo "  -s, --storage-account NAME   Storage account name (default: qrcodeapistorage)"
      echo "  -c, --container-name NAME    Container name (default: qrcodes)"
      echo "  -i, --identity-name NAME     Managed identity name (default: qr-api-identity)"
      echo "  -p, --service-principal-name Name for local dev service principal (default: qr-api-local-dev)"
      echo "  -h, --help                   Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Check if logged in to Azure
echo "Checking Azure login..."
az account show &> /dev/null || { echo "Not logged in to Azure. Please run 'az login' first."; exit 1; }
echo "✓ Logged in to Azure"

# Create resource group
echo "Creating resource group '$RESOURCE_GROUP' in '$LOCATION'..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" || { echo "Failed to create resource group"; exit 1; }
echo "✓ Resource group created"

# Create storage account with local authentication disabled (for policy compliance)
echo "Creating storage account '$STORAGE_ACCOUNT'..."
az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --allow-shared-key-access false \
  --enable-hierarchical-namespace false || { echo "Failed to create storage account"; exit 1; }
echo "✓ Storage account created"

# Create a user-assigned managed identity
echo "Creating managed identity '$IDENTITY_NAME'..."
az identity create \
  --name "$IDENTITY_NAME" \
  --resource-group "$RESOURCE_GROUP" || { echo "Failed to create managed identity"; exit 1; }
echo "✓ Managed identity created"

# Get the storage account ID
echo "Getting storage account ID..."
STORAGE_ID=$(az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --query id -o tsv)
echo "✓ Storage account ID: $STORAGE_ID"

# Get the managed identity principal ID
echo "Getting managed identity principal ID..."
IDENTITY_PRINCIPAL_ID=$(az identity show --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" --query principalId -o tsv)
echo "✓ Managed identity principal ID: $IDENTITY_PRINCIPAL_ID"

# Assign Storage Blob Data Contributor role
echo "Assigning Storage Blob Data Contributor role to managed identity..."
az role assignment create \
  --assignee-object-id "$IDENTITY_PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" \
  --scope "$STORAGE_ID" || { echo "Failed to assign role"; exit 1; }
echo "✓ Role assigned"

# Create the container
echo "Creating container '$CONTAINER_NAME'..."
az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_ACCOUNT" \
  --auth-mode login || { echo "Failed to create container"; exit 1; }
echo "✓ Container created"

# Get current user information for local development with passwordless authentication
echo "Configuring permissions for local development with passwordless authentication..."

# Get the current user's object ID
CURRENT_USER=$(az ad signed-in-user show --query userPrincipalName -o tsv 2>/dev/null)
if [ -z "$CURRENT_USER" ]; then
  echo "⚠️ Could not determine current user. Passwordless authentication may not work locally."
  echo "    For local development, make sure you're signed in with 'az login'."
  LOCAL_AUTH_CONFIGURED=false
else
  echo "✓ Current user: $CURRENT_USER"
  
  # Assign Storage Blob Data Contributor role to the current user
  echo "Assigning Storage Blob Data Contributor role to your user account..."
  az role assignment create \
    --assignee "$CURRENT_USER" \
    --role "Storage Blob Data Contributor" \
    --scope "$STORAGE_ID" > /dev/null 2>&1
  
  if [ $? -eq 0 ]; then
    echo "✓ RBAC role assigned to your user account"
    LOCAL_AUTH_CONFIGURED=true
  else
    echo "⚠️ Could not assign role to your user account. You might need admin permissions."
    LOCAL_AUTH_CONFIGURED=false
  fi
  
  # Get tenant ID for environment configuration
  TENANT_ID=$(az account show --query tenantId -o tsv 2>/dev/null)
  if [ -n "$TENANT_ID" ]; then
    echo "✓ Azure Tenant ID: $TENANT_ID"
  else
    echo "⚠️ Could not determine Azure Tenant ID"
  fi
fi
  
# Create .env file for local development
echo "Creating/updating .env file with Azure configuration..."
if [ -f .env ]; then
  echo "✓ Using existing .env file"
elif [ -f .env.example ]; then
  cp .env.example .env
  echo "✓ Created .env file from .env.example"
else
  touch .env
  echo "✓ Created new .env file"
fi

# Update .env file with Azure configuration
# Remove existing Azure-related settings
sed -i '' '/AZURE_STORAGE_ACCOUNT_NAME/d' .env 2>/dev/null
sed -i '' '/AZURE_TENANT_ID/d' .env 2>/dev/null  
sed -i '' '/AZURE_CLIENT_ID/d' .env 2>/dev/null  
sed -i '' '/AZURE_CLIENT_SECRET/d' .env 2>/dev/null
sed -i '' '/STORAGE_TYPE/d' .env 2>/dev/null

# Add new Azure settings for passwordless authentication
cat >> .env << EOL
# Azure Storage configuration (updated by setup-azure-storage.sh)
STORAGE_TYPE=azure
CONTAINER_NAME=$CONTAINER_NAME
AZURE_STORAGE_ACCOUNT_NAME=$STORAGE_ACCOUNT

# Using DefaultAzureCredential for passwordless authentication
# No need for AZURE_CLIENT_ID or AZURE_CLIENT_SECRET when using passwordless auth
# The application will use your Azure CLI credentials when running locally
EOL

if [ -n "$TENANT_ID" ]; then
  echo "AZURE_TENANT_ID=$TENANT_ID" >> .env
fi

echo "✓ Updated .env file with Azure configuration"
  
echo "=============================================================="
echo "✅ Setup complete! Your QR Code API is now configured to use"
echo "   Azure Storage with Managed Identity authentication."
echo ""
echo "   Storage Account: $STORAGE_ACCOUNT"
echo "   Container:       $CONTAINER_NAME"
echo ""
if [ "$LOCAL_AUTH_CONFIGURED" = "true" ]; then
  echo "   For local development, passwordless authentication is set up"
  echo "   using your Azure CLI credentials."
  echo ""
  echo "   If you get authentication errors, try these steps:"
  echo "   1. Make sure you're logged in: az login"
  echo "   2. Wait a few minutes for RBAC permissions to propagate"
  echo "   3. Verify your role assignments: az role assignment list --all"
else
  echo "   ⚠️ Passwordless authentication could not be fully configured."
  echo "   You may need to request necessary permissions from your admin."
  echo ""
  echo "   More info: https://aka.ms/azsdk/js/identity/defaultazurecredential"
fi
echo ""
echo "   To start the API:"
echo "   npm install"
echo "   npm start"
echo "=============================================================="
