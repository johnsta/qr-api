param location string = resourceGroup().location
param appServiceName string
param storageAccountName string
param applicationInsightsName string
param managedIdentityName string
param sku string = 'B1'

var appServicePlanName = '${appServiceName}-plan'

// Define App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: sku
    tier: sku == 'B1' ? 'Basic' : (sku == 'F1' ? 'Free' : 'Standard')
    capacity: 1
  }
  kind: 'linux'
  properties: {
    reserved: true // Required for Linux
  }
}

module storageAccount 'modules/storageAccount.bicep' = {
  name: 'storageAccount'
  params: {
    storageAccountName: storageAccountName
    location: location
  }
}

module appService 'modules/appService.bicep' = {
  name: 'appService'
  params: {
    appServiceName: appServiceName
    appServicePlanId: appServicePlan.id
    location: location
    startupCommand: 'bash startup.sh'
  }
}

module applicationInsights 'modules/applicationInsights.bicep' = {
  name: 'applicationInsights'
  params: {
    applicationInsightsName: applicationInsightsName
    location: location
  }
}

module managedIdentity 'modules/managedIdentity.bicep' = {
  name: 'managedIdentity'
  params: {
    managedIdentityName: managedIdentityName
    location: location
  }
}

module rbac 'modules/rbac.bicep' = {
  name: 'rbac'
  params: {
    identityPrincipalId: managedIdentity.outputs.identityPrincipalId
    storageAccountId: storageAccount.outputs.storageAccountId
  }
}

// Configure app service settings
resource appServiceSettings 'Microsoft.Web/sites/config@2021-02-01' = {
  name: '${appServiceName}/appsettings'
  properties: {
    STORAGE_TYPE: 'azure'
    CONTAINER_NAME: 'qrcodes'
    AZURE_STORAGE_ACCOUNT_NAME: storageAccount.outputs.storageAccountName
    APPINSIGHTS_INSTRUMENTATIONKEY: applicationInsights.outputs.applicationInsightsId
    MANAGED_IDENTITY_CLIENT_ID: managedIdentity.outputs.identityPrincipalId
    AZURE_STORAGE_USE_MANAGED_IDENTITY: 'true'
  }
  dependsOn: [
    appService
  ]
}

// Add managed identity to app service
resource appServiceIdentity 'Microsoft.Web/sites/config@2021-02-01' = {
  name: '${appServiceName}/web'
  properties: {
    managedServiceIdentity: {
      type: 'UserAssigned'
      userAssignedIdentities: {
        '${managedIdentity.outputs.identityId}': {}
      }
    }
  }
  dependsOn: [
    appService
  ]
}

output appServiceUrl string = 'https://${appService.outputs.name}.azurewebsites.net'
output appServicePlanId string = appServicePlan.id
output appServiceName string = appService.outputs.name
output storageAccountId string = storageAccount.outputs.storageAccountId
output applicationInsightsId string = applicationInsights.outputs.applicationInsightsId
output identityPrincipalId string = managedIdentity.outputs.identityPrincipalId
