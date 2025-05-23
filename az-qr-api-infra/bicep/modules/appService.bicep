 param appServiceName    string
 param appServicePlanId  string
 param location          string
 param runtimeStack      string = 'NODE|18-lts'
 param startupCommand    string = 'bash startup.sh'

 resource appService 'Microsoft.Web/sites@2021-02-01' = {
   name: appServiceName
   location: location
   kind: 'app,linux'
   properties: {
     serverFarmId: appServicePlanId
     httpsOnly: true
     siteConfig: {
      linuxFxVersion: runtimeStack
      appCommandLine: startupCommand
      http20Enabled: true
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'NODE_ENV'
          value: 'production'
        }
      ]
     }
   }
 }

 output name string = appService.name
 output id   string = appService.id
