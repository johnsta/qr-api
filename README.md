# QR Code Generator API

A FastAPI-based REST API for generating, storing, and managing QR codes with multiple storage backend options.

## Features

- Generate QR codes from text/URL data
- Custom QR code size
- Upload pre-generated QR codes
- Retrieve QR code images
- Track QR code metadata (creation time, access count)
- Multiple storage backends:
  - MinIO (open-source, S3-compatible - great for local development)
  - Azure Blob Storage (for production deployment)
- Managed Identity authentication (for Azure)
- Docker Compose setup for local development
- Comprehensive API testing using httpYac

## Prerequisites

- Python 3.9+
- Docker and Docker Compose (for local MinIO development)
- Azure CLI and subscription (for Azure deployment only)

## Local Development

### Option 1: Using Docker Compose with MinIO (Recommended)

1. **Clone the repository**

2. **Set up environment variables**
   ```bash
   # Copy the sample env file
   cp .env.sample .env
   ```

3. **Start the API and MinIO with Docker Compose**
   ```bash
   docker-compose up -d
   ```

   The API will be available at http://localhost:8000
   The MinIO console will be available at http://localhost:9001 (user: minioadmin, password: minioadmin)

### Option 2: Running Locally with Python

1. **Clone the repository**

2. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

3. **Setup MinIO**
   
   Either:
   - Run MinIO using Docker: 
     ```bash
     docker run -p 9000:9000 -p 9001:9001 quay.io/minio/minio server /data --console-address ":9001"
     ```
   - Or install MinIO directly on your system

4. **Set up environment variables**
   ```bash
   # Copy the sample env file and edit as needed
   cp .env.sample .env
   ```

5. **Run the application**
   ```bash
   uvicorn app:app --reload
   ```

   The API will be available at http://localhost:8000

6. **API Documentation**
   
   Visit http://localhost:8000/docs for the Swagger UI documentation.

## Deployment to Azure

1. **Login to Azure**
   ```bash
   az login
   ```

2. **Create Azure resources manually**
   ```bash
   # Create resource group
   az group create --name qr-code-api-rg --location eastus
   
   # Create storage account
   az storage account create --name qrcodeapistg --resource-group qr-code-api-rg --location eastus --sku Standard_LRS
   
   # Create App Service plan
   az appservice plan create --name qr-code-api-plan --resource-group qr-code-api-rg --sku B1 --is-linux
   
   # Create Web App
   az webapp create --resource-group qr-code-api-rg --plan qr-code-api-plan --name your-qr-code-api --runtime "PYTHON|3.9"
   
   # Configure environment variables
   az webapp config appsettings set --resource-group qr-code-api-rg --name your-qr-code-api \
     --settings STORAGE_TYPE=azure CONTAINER_NAME=qrcodes AZURE_STORAGE_ACCOUNT_NAME=qrcodeapistg
   
   # Enable managed identity
   az webapp identity assign --resource-group qr-code-api-rg --name your-qr-code-api
   
   # Get the identity principal ID
   IDENTITY_PRINCIPAL_ID=$(az webapp identity show --resource-group qr-code-api-rg --name your-qr-code-api --query principalId -o tsv)
   
   # Get the storage account ID
   STORAGE_ACCOUNT_ID=$(az storage account show --name qrcodeapistg --resource-group qr-code-api-rg --query id -o tsv)
   
   # Grant the identity access to the storage account
   az role assignment create --assignee $IDENTITY_PRINCIPAL_ID --role "Storage Blob Data Contributor" --scope $STORAGE_ACCOUNT_ID
   ```

3. **Deploy the code to Azure App Service**
   ```bash
   # Create a zip package
   zip -r api.zip app.py requirements.txt
   
   # Deploy the package
   az webapp deployment source config-zip --resource-group qr-code-api-rg --name your-qr-code-api --src ./api.zip
   ```

## Testing the API

This project includes comprehensive API testing using httpYac, both through VS Code and the command line.

### Testing Files

- `api-tests.http` - Main test file with dynamic variables and complete test flow
- `advanced-tests.http` - Enhanced tests with environment management
- `test-api.sh` - Automated test script
- `http-testing-guide.md` - Detailed testing guide

### Using httpYac

1. **Install httpYac**:
   ```bash
   # VS Code Extension
   # Install from VS Code Extension Marketplace: search for "httpYac"
   
   # Command Line
   npm install -g httpyac
   ```

2. **Run Tests**:
   ```bash
   # Run all tests
   httpyac api-tests.http
   
   # Run interactive mode
   httpyac api-tests.http --interactive
   
   # Run tests with specified environment
   httpyac api-tests.http --env local
   
   # Run automated test script
   ./test-api.sh
   ```

3. **View Test Results**:
   The test results will appear in the terminal, and any downloaded QR codes will be saved to the `test-output` folder.

For more detailed information, see `http-testing-guide.md`.

## Storage Configuration

The API supports two storage backends:

### MinIO (Default)

MinIO is an open-source, S3-compatible object storage that's perfect for local development and testing. It provides:

- Easy local setup with Docker
- S3-compatible API
- Web-based management console
- No cloud dependencies

Configure MinIO in your `.env` file:
```
STORAGE_TYPE=minio
CONTAINER_NAME=qrcodes
MINIO_ENDPOINT=localhost:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_SECURE=false
```

### Azure Blob Storage

When deploying to production on Azure, you can use Azure Blob Storage:

- Managed by Azure
- Scalable and reliable
- Works seamlessly with other Azure services
- Supports Managed Identity authentication

Configure Azure Blob Storage in your `.env` file:
```
STORAGE_TYPE=azure
CONTAINER_NAME=qrcodes
AZURE_STORAGE_CONNECTION_STRING=your_connection_string  # For local development
AZURE_STORAGE_ACCOUNT_NAME=your_storage_account_name    # For production with Managed Identity
```

## API Endpoints

### Generate QR Code
```http
POST /api/qrcodes
Content-Type: application/json

{
  "data": "https://example.com",
  "size": 300
}
```

### Upload QR Code
```http
PUT /api/qrcodes/{code_id}
Content-Type: image/png
X-QR-Data: https://example.com
X-QR-Size: 300

(binary PNG payload)
```

### Get QR Code
```http
GET /api/qrcodes/{code_id}
```

### Get Metadata
```http
GET /api/qrcodes/{code_id}/metadata
```

### Check if QR Code Exists
```http
HEAD /api/qrcodes/{code_id}
```

### Delete QR Code
```http
DELETE /api/qrcodes/{code_id}
```

### Check Existence
```http
HEAD /api/qrcodes/{code_id}
```

### Delete QR Code
```http
DELETE /api/qrcodes/{code_id}
```

## Security Features

- HTTPS only
- Managed Identity authentication to Azure Storage
- TLS 1.2 enforcement
- Secure connection strings handling
- No public access to storage container

## Monitoring

- Application Insights integration
- Access tracking
- Usage metrics

## Infrastructure as Code

The `infra/main.bicep` file contains the complete infrastructure definition:
- App Service (Linux)
- Storage Account
- Application Insights
- Managed Identity
- RBAC assignments

## CI/CD

GitHub Actions workflow is configured for automated deployments:
- Triggers on push to main branch
- Builds and tests the application
- Deploys to Azure App Service

## License

MIT
