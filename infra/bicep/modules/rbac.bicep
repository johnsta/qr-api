param identityPrincipalId string
param storageAccountId string

var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor role ID

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(identityPrincipalId, storageBlobDataContributorRoleId, storageAccountId)
  properties: {
    principalId: identityPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalType: 'ServicePrincipal'
  }
  scope: resourceGroup()
}
