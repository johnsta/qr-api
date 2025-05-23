# QR Code Generator API

A RESTful API service for generating, storing, and managing QR codes with multiple storage backends.

## Features

- Generate QR codes from URLs, text, vCard data, or WiFi information
- Store QR codes in Azure Blob Storage or MinIO (S3-compatible storage)
- Retrieve QR codes and metadata
- Custom QR code size
- Track QR code access statistics
- Health endpoint for monitoring

## Technologies

- Node.js
- Express.js
- Azure Blob Storage / MinIO
- QRCode library
- Docker & Docker Compose

## Requirements

- Node.js 18.x or higher
- npm or yarn
- Docker and Docker Compose (for local development with MinIO)
- Azure account (for cloud deployment)

## Local Development

### Setup with Docker Compose

1. Clone this repository
2. Run the services using Docker Compose:

```bash
docker-compose up -d
```

This will start:
- MinIO at http://localhost:9000 (Console: http://localhost:9001)
- QR Code API at http://localhost:8000

Note: Environment variables for the API are already configured in the docker-compose.yml file. No need to create a .env file for Docker Compose setup.

### Setup without Docker

When not using Docker, you have two main options for storage:

#### Option 1: Use Azure Storage

You can connect to Azure Storage using either a connection string (if allowed by your organization's policies) or Managed Identity (recommended for security).

1. Clone this repository
2. Install dependencies:

```bash
npm install
```

3. Create a `.env` file with your configuration:

```bash
# Copy the example environment file
cp .env.example .env

# Edit the .env file with Azure storage settings
nano .env  # or use your preferred editor
```

4. Configure the `.env` file to use Azure Storage:

**Option A: Using Connection String (if allowed by your organization)**
```
STORAGE_TYPE=azure
CONTAINER_NAME=qrcodes
AZURE_STORAGE_ACCOUNT_NAME=yourstorageaccount
AZURE_STORAGE_CONNECTION_STRING=your_connection_string
```

**Option B: Using Passwordless Authentication with DefaultAzureCredential (recommended)**
```
STORAGE_TYPE=azure
CONTAINER_NAME=qrcodes
AZURE_STORAGE_ACCOUNT_NAME=yourstorageaccount

# No client ID or secret needed - uses your Azure CLI login credentials
# See: https://aka.ms/azsdk/js/identity/defaultazurecredential
```

You'll need to sign in with Azure CLI (`az login`) and have the "Storage Blob Data Contributor" role assigned to your account for the storage resource.

> **Automated Setup**: Instead of configuring this manually, you can run our developer setup script:
> ```bash
> # Make sure you're logged in to Azure first
> az login
> 
> # Run the setup script
> ./dev-setup-storagetype-azure.sh
> ```
> This will create all the necessary Azure resources and configure your local environment automatically.

5. Run the API:

```bash
npm start
```

#### Option 2: Connect to MinIO

If you want to use MinIO for local development:

1. Clone this repository
2. Install dependencies:

```bash
npm install
```

3. Create a `.env` file and configure it to point to your MinIO instance:

```
STORAGE_TYPE=minio
CONTAINER_NAME=qrcodes
MINIO_ENDPOINT=localhost:9000  # or your custom MinIO host
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_SECURE=false  # Set to true if using HTTPS
```

> **Automated Setup**: Instead of configuring this manually, you can run our developer setup script:
> ```bash
> # Make sure Docker is running first
> ./dev-setup-storagetype-minio.sh
> ```
> This will configure your local environment for MinIO and offer to start Docker containers if needed.

4. Run the API:

```bash
npm start
```

For most local development cases, we recommend using the Docker Compose setup as it's simpler and ensures all dependencies are properly configured.

## API Endpoints

### Create a QR Code

```
POST /api/qrcodes
```

Request body:
```json
{
  "data": "https://example.com",
  "size": 300
}
```

### Upload a QR Code

```
PUT /api/qrcodes/{code_id}
```

Headers:
- `X-QR-Data`: The data encoded in the QR code
- `X-QR-Size`: The size of the QR code (default: 300)

Body: QR code image file (PNG)

### Get a QR Code

```
GET /api/qrcodes/{code_id}
```

### Get QR Code Metadata

```
GET /api/qrcodes/{code_id}/metadata
```

### Check if a QR Code Exists

```
HEAD /api/qrcodes/{code_id}
```

### Delete a QR Code

```
DELETE /api/qrcodes/{code_id}
```

### Health Check

```
GET /health
```

## Testing

Run the test script:

```bash
./test-api.sh
```

Or run the unit tests:

```bash
npm test
```

## Deployment

### Setting up Local Development with Azure Storage

To help developers configure their local environment to connect to Azure Storage, we've provided a setup script:

```bash
# Run the setup script (login to Azure first with 'az login')
./dev-setup-storagetype-azure.sh
```

This script will:
1. Create a resource group in your Azure subscription
2. Create an Azure Storage account with local authentication disabled (for policy compliance)
3. Create a user-assigned managed identity
4. Assign the necessary RBAC roles
5. Create a container for QR codes
6. Set up passwordless authentication for local development using your Azure CLI credentials
7. Configure your local `.env` file automatically

You can customize the script with various options:
```bash
./dev-setup-storagetype-azure.sh --help
```

Options:
- `--resource-group` or `-g`: Resource group name (default: qr-api-resources)
- `--location` or `-l`: Azure location (default: southeastasia)
- `--storage-account` or `-s`: Storage account name (default: qrcodeapistorage)
- `--container-name` or `-c`: Container name (default: qrcodes)
- `--identity-name` or `-i`: Managed identity name (default: qr-api-identity)

### Azure Deployment

1. Run the deployment script:

```bash
chmod +x ./deploy.sh
./deploy.sh
```

## Demo

**Delete the entire autoscale setting (removes all rules for the plan)**
az monitor autoscale delete \
  --resource-group "$RESOURCE_GROUP" \
  --name "${PLAN_NAME}-autoscale"

## License

MIT
