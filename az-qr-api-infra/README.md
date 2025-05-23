# Azure QR Code Generator API Infrastructure

This project contains Bicep templates for provisioning and deploying the Azure infrastructure required for the QR Code Generator API. The infrastructure includes an Azure App Service, Storage Account, Application Insights, Managed Identity, and Role-Based Access Control (RBAC) assignments.

## Project Structure

- **bicep/**: Contains Bicep files for resource definitions and parameters.
  - **main.bicep**: The main Bicep file that orchestrates the deployment of all resources.
  - **modules/**: Contains modular Bicep files for individual resources.
    - **appService.bicep**: Defines the Azure App Service resource.
    - **storageAccount.bicep**: Provisions the Azure Storage Account.
    - **applicationInsights.bicep**: Sets up Application Insights for monitoring.
    - **managedIdentity.bicep**: Creates a Managed Identity for the App Service.
    - **rbac.bicep**: Handles the Role-Based Access Control (RBAC) assignments.
  - **parameters/**: Contains parameter files for different environments.
    - **dev.parameters.json**: Parameter values for the development environment.
    - **prod.parameters.json**: Parameter values for the production environment.

- **scripts/**: Contains deployment scripts.
  - **deploy.sh**: Shell script for automating the deployment of Bicep templates.
  - **deploy.ps1**: PowerShell script for automating the deployment of Bicep templates on Windows.

- **.github/**: Contains GitHub Actions workflows.
  - **workflows/**: Directory for workflow files.
    - **deploy-infra.yml**: GitHub Actions workflow for automating infrastructure deployment.

- **README.md**: Documentation for the project, including deployment instructions and prerequisites.

- **.gitignore**: Specifies files and directories to be ignored by Git.

## Prerequisites

- Azure CLI installed and configured.
- Bicep CLI installed.
- An active Azure subscription.

## Deployment Instructions

1. Clone the repository.
2. Navigate to the `az-qr-api-infra` directory.
3. Deploy the infrastructure using the provided scripts.

### Using the Shell Script (macOS/Linux)

Run the following command to deploy the infrastructure to the development environment:

```bash
./scripts/deploy.sh -e dev
```

For production deployment:

```bash
./scripts/deploy.sh -e prod
```

You can also specify a location:

```bash
./scripts/deploy.sh -e dev -l westus2
```

### Using the PowerShell Script (Windows)

Run the following command to deploy the infrastructure to the development environment:

```powershell
.\scripts\deploy.ps1 -Environment dev
```

For production deployment:

```powershell
.\scripts\deploy.ps1 -Environment prod
```

You can also specify a location:

```powershell
.\scripts\deploy.ps1 -Environment dev -Location westus2
```

## Deployment Process

The deployment script performs the following actions:

1. Logs in to Azure using `az login`.
2. Creates the resource group if it doesn't exist.
3. Previews the changes using the `what-if` deployment option.
4. Deploys the Bicep template with the specified parameters.
5. Creates the storage container for QR codes.
6. Packages and deploys the API application to the Azure App Service.
7. Configures the App Service settings for storage and identity.
8. Restarts the App Service to apply all configurations.
9. Verifies the deployment by checking the health endpoint.

For Windows users, run the following command:

```powershell
./scripts/deploy.ps1
```

## License

This project is licensed under the MIT License.