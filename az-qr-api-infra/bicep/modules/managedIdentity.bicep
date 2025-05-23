param location string
param managedIdentityName string

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
}

output identityPrincipalId string = managedIdentity.properties.principalId
output identityId string = managedIdentity.id
