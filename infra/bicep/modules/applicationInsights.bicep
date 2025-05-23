param location string
param applicationInsightsName string

resource applicationInsights 'microsoft.insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

output applicationInsightsName string = applicationInsights.name
output applicationInsightsId string = applicationInsights.id
