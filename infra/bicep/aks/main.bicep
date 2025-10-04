// ===============================================================================
// AKS CLUSTER with Istio Add-on
// ===============================================================================

@description('Azure region')
param location string

@description('Environment name')
param environment string

@description('Resource prefix')
param prefix string

@description('Cluster name (cluster-a or cluster-b)')
param clusterName string

@description('Resource tags')
param tags object

@description('Log Analytics Workspace ID')
param logAnalyticsWorkspaceId string

@description('ACR ID for pull permissions')
param acrId string

// ===============================================================================
// VIRTUAL NETWORK
// ===============================================================================

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: '${prefix}-vnet-${clusterName}-${environment}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        clusterName == 'cluster-a' ? '10.1.0.0/16' : '10.2.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'aks-subnet'
        properties: {
          addressPrefix: clusterName == 'cluster-a' ? '10.1.0.0/20' : '10.2.0.0/20'
        }
      }
    ]
  }
}

// ===============================================================================
// AKS CLUSTER
// ===============================================================================

resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-10-01' = {
  name: '${prefix}-aks-${clusterName}-${environment}'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: '1.28.3'
    dnsPrefix: '${prefix}-${clusterName}-${environment}'
    enableRBAC: true
    
    agentPoolProfiles: [
      {
        name: 'system'
        count: 3
        vmSize: 'Standard_D4s_v3'
        mode: 'System'
        osType: 'Linux'
        type: 'VirtualMachineScaleSets'
        vnetSubnetID: vnet.properties.subnets[0].id
        enableAutoScaling: true
        minCount: 3
        maxCount: 6
      }
      {
        name: 'apps'
        count: 3
        vmSize: 'Standard_D8s_v3'
        mode: 'User'
        osType: 'Linux'
        type: 'VirtualMachineScaleSets'
        vnetSubnetID: vnet.properties.subnets[0].id
        enableAutoScaling: true
        minCount: 3
        maxCount: 10
      }
    ]
    
    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkDataplane: 'cilium'
      networkPolicy: 'cilium'
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'
    }
    
    serviceMeshProfile: {
      mode: 'Istio'
      istio: {
        components: {
          ingressGateways: [
            {
              enabled: true
              mode: 'External'
            }
          ]
        }
      }
    }
    
    addonProfiles: {
      azureKeyvaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation: 'true'
        }
      }
      azurePolicy: {
        enabled: true
      }
    }
    
    oidcIssuerProfile: {
      enabled: true
    }
    
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
      defender: {
        securityMonitoring: {
          enabled: true
        }
      }
    }
    
    azureMonitorProfile: {
      metrics: {
        enabled: true
        kubeStateMetrics: {
          metricLabelsAllowlist: ''
          metricAnnotationsAllowList: ''
        }
      }
    }
  }
}

// ===============================================================================
// DIAGNOSTIC SETTINGS
// ===============================================================================

resource aksDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: aksCluster
  name: 'aks-diagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'kube-apiserver'
        enabled: true
      }
      {
        category: 'kube-controller-manager'
        enabled: true
      }
      {
        category: 'kube-scheduler'
        enabled: true
      }
      {
        category: 'kube-audit'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// ===============================================================================
// ACR PULL ROLE ASSIGNMENT
// ===============================================================================

resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aksCluster.id, acrId, 'AcrPull')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: aksCluster.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}

// ===============================================================================
// OUTPUTS
// ===============================================================================

output clusterName string = aksCluster.name
output clusterFqdn string = aksCluster.properties.fqdn
output clusterIdentityPrincipalId string = aksCluster.identity.principalId
output oidcIssuerUrl string = aksCluster.properties.oidcIssuerProfile.issuerURL
