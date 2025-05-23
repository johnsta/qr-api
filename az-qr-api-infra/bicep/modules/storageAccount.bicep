param storageAccountName string
param location string
param sku string = 'Standard_LRS'

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: sku
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    allowSharedKeyAccess: false  // Disabling local authentication as required by policy
    minimumTlsVersion: 'TLS1_2'
  }
  tags: {
    'Az.Sec.DisableLocalAuth.Storage::Skip': 'true'  // This tag allows us to opt-out of the policy if needed
  }
}

output storageAccountName string = storageAccount.name
output storageAccountId string = storageAccount.id
