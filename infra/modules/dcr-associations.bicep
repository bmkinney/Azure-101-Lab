// dcr-associations.bicep - Associate VMs with the Data Collection Rule
// Deployed after both the DCR and the VMs (with AMA) are ready.

@description('Name of VM1.')
param vm1Name string

@description('Name of VM2.')
param vm2Name string

@description('Resource ID of the Data Collection Rule.')
param dataCollectionRuleId string

resource vm1 'Microsoft.Compute/virtualMachines@2024-07-01' existing = {
  name: vm1Name
}

resource vm2 'Microsoft.Compute/virtualMachines@2024-07-01' existing = {
  name: vm2Name
}

resource dcr1 'Microsoft.Insights/dataCollectionRuleAssociations@2023-03-11' = {
  name: '${vm1Name}-dcr-association'
  scope: vm1
  properties: {
    dataCollectionRuleId: dataCollectionRuleId
  }
}

resource dcr2 'Microsoft.Insights/dataCollectionRuleAssociations@2023-03-11' = {
  name: '${vm2Name}-dcr-association'
  scope: vm2
  properties: {
    dataCollectionRuleId: dataCollectionRuleId
  }
}
