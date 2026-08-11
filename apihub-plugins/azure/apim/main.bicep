// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Azure infra for the real-time Azure APIM -> API hub on-ramp.
// Graph-free: App Registration is created manually in the Azure Portal
// (README Step 1) and its Application (client) id is passed here as `appId`.
// Idempotent by nature (re-deploy converges; no "already exists" errors).

targetScope = 'resourceGroup'

@description('Name of the EXISTING APIM service in this resource group')
param apimName string
@description('Region for created resources (azure_setup.sh passes the APIM region)')
param location string
@description('App (client) ID of the pre-created App Registration = WIF audience')
param appId string
@description('Tags applied to all created resources')
param tags object = {}
@description('Optional: create Application Insights + Log Analytics for function logs')
param enableAppInsights bool = false

param gcpProject string
param projectNumber string
param gcpLocation string
param instanceId string
param poolId string = 'apihub-azure-onramp-pool'
param providerId string = 'azure-apim-oidc'
param saName string = 'apihub-azure-onramp-sa'
param apihubHost string = 'https://apihub.googleapis.com'
param pluginId string = 'system-azure-apim'
param deploymentTypeId string = 'azure-apim'
param apimApiVersion string = '2024-05-01'

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = { name: apimName }

var sfx       = uniqueString(resourceGroup().id)
var funcName  = 'func-apihub-onramp'
var planName  = 'plan-apihub-onramp'
var uamiName  = 'id-apihub-onramp'
var lawName   = 'law-apihub-onramp'
var appiName  = 'appi-apihub-onramp'
var storageNm = toLower('stapihubonramp${substring(sfx, 0, 6)}')
var wifAud    = '//iam.googleapis.com/projects/${projectNumber}/locations/global/workloadIdentityPools/${poolId}/providers/${providerId}'
var saEmail   = '${saName}@${gcpProject}.iam.gserviceaccount.com'

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: uamiName
  location: location
  tags: tags
}

// ---- Optional Application Insights (workspace-based) for function logs ----
resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = if (enableAppInsights) {
  name: lawName
  location: location
  tags: tags
  properties: { sku: { name: 'PerGB2018' }, retentionInDays: 30 }
}
resource appi 'Microsoft.Insights/components@2020-02-02' = if (enableAppInsights) {
  name: appiName
  location: location
  kind: 'web'
  tags: tags
  properties: { Application_Type: 'web', WorkspaceResourceId: law.id }
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageNm
  location: location
  tags: tags
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: { minimumTlsVersion: 'TLS1_2', allowBlobPublicAccess: false }
}
resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  tags: tags
  sku: { name: 'Y1', tier: 'Dynamic' }
  kind: 'functionapp'
  properties: { reserved: true }
}
resource func 'Microsoft.Web/sites@2023-12-01' = {
  name: funcName
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: { type: 'UserAssigned', userAssignedIdentities: { '${uami.id}': {} } }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'Node|20'
      appSettings: concat([
        { name: 'AzureWebJobsStorage', value: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storage.listKeys().keys[0].value}' }
        { name: 'FUNCTIONS_EXTENSION_VERSION', value: '~4' }
        { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'node' }
        { name: 'AZURE_CLIENT_ID', value: uami.properties.clientId }
        { name: 'AZURE_TENANT_ID', value: tenant().tenantId }
        { name: 'WIF_APP_ID_URI', value: 'api://${appId}' }
        { name: 'WIF_AUDIENCE', value: wifAud }
        { name: 'WIF_SA_EMAIL', value: saEmail }
        { name: 'PROJECT', value: gcpProject }
        { name: 'LOCATION', value: gcpLocation }
        { name: 'APIHUB_HOST', value: apihubHost }
        { name: 'INSTANCE_ID', value: instanceId }
        { name: 'PLUGIN_ID', value: pluginId }
        { name: 'DEPLOYMENT_TYPE_ID', value: deploymentTypeId }
        { name: 'APIM_API_VERSION', value: apimApiVersion }
      ], enableAppInsights ? [
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appi.properties.ConnectionString }
      ] : [])
    }
  }
}

// ---- Reader on the existing APIM for the function's identity ----
var readerRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')
resource reader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(apim.id, uami.id, readerRole)
  scope: apim
  properties: {
    roleDefinitionId: readerRole
    principalId: uami.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output uamiPrincipalId string = uami.properties.principalId
output functionAppName string  = func.name
output wifAudience string       = wifAud
