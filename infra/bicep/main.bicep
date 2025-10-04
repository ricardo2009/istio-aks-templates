// ===============================================================================
// MAIN BICEP - Microsoft-First AKS + Istio Add-on Solution
// ===============================================================================
// Main orchestration file for the complete infrastructure
// ===============================================================================

targetScope = 'subscription'

@description('Environment name (dev, hml, prod)')
param environment string = 'dev'

@description('Azure region for primary resources')
param location string = 'eastus'

@description('Azure region for secondary resources')
param secondaryLocation string = 'westus'

@description('Resource name prefix')
param prefix string = 'istio'

@description('Tags to apply to all resources')
param tags object = {
  Environment: environment
  ManagedBy: 'Bicep'
  Solution: 'AKS-Istio-APIM'
}

// ===============================================================================
// RESOURCE GROUPS
// ===============================================================================

resource rgCore 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${prefix}-rg-core-${environment}'
  location: location
  tags: tags
}

resource rgAksA 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${prefix}-rg-aks-a-${environment}'
  location: location
  tags: tags
}

resource rgAksB 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${prefix}-rg-aks-b-${environment}'
  location: secondaryLocation
  tags: tags
}

// ===============================================================================
// CORE INFRASTRUCTURE
// ===============================================================================

module coreInfra 'rg-core/main.bicep' = {
  name: 'coreInfra-${environment}'
  scope: rgCore
  params: {
    location: location
    environment: environment
    prefix: prefix
    tags: tags
  }
}

// ===============================================================================
// AKS CLUSTER A (Orders)
// ===============================================================================

module aksClusterA 'aks/main.bicep' = {
  name: 'aksClusterA-${environment}'
  scope: rgAksA
  params: {
    location: location
    environment: environment
    prefix: prefix
    clusterName: 'cluster-a'
    tags: tags
    logAnalyticsWorkspaceId: coreInfra.outputs.logAnalyticsWorkspaceId
    acrId: coreInfra.outputs.acrId
  }
}

// ===============================================================================
// AKS CLUSTER B (Payments)
// ===============================================================================

module aksClusterB 'aks/main.bicep' = {
  name: 'aksClusterB-${environment}'
  scope: rgAksB
  params: {
    location: secondaryLocation
    environment: environment
    prefix: prefix
    clusterName: 'cluster-b'
    tags: tags
    logAnalyticsWorkspaceId: coreInfra.outputs.logAnalyticsWorkspaceId
    acrId: coreInfra.outputs.acrId
  }
}

// ===============================================================================
// OUTPUTS
// ===============================================================================

output resourceGroupCore string = rgCore.name
output resourceGroupAksA string = rgAksA.name
output resourceGroupAksB string = rgAksB.name

output aksClusterAName string = aksClusterA.outputs.clusterName
output aksClusterBName string = aksClusterB.outputs.clusterName

output acrLoginServer string = coreInfra.outputs.acrLoginServer
output apimGatewayUrl string = coreInfra.outputs.apimGatewayUrl
output cosmosDbEndpoint string = coreInfra.outputs.cosmosDbEndpoint
output keyVaultUri string = coreInfra.outputs.keyVaultUri
