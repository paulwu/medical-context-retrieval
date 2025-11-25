// Medical RAG System - Azure Infrastructure
// Deploys: Key Vault, Container Registry, Container Apps Environment, and Container App

@description('Location for all resources')
param location string = resourceGroup().location

@description('Environment name (dev, staging, prod)')
param environmentName string = 'prod'

@description('Application name')
param appName string = 'medical-rag'

@description('Container image tag')
param imageTag string = 'latest'

@description('Azure OpenAI endpoint')
@secure()
param azureOpenAIEndpoint string

@description('Azure OpenAI API key')
@secure()
param azureOpenAIApiKey string

@description('Azure OpenAI embedding model name')
param embeddingModel string = 'text-embedding-ada-002'

@description('Azure OpenAI chat model name')
param chatModel string = 'gpt-5-mini'

// Variables
var uniqueSuffix = uniqueString(resourceGroup().id)
var keyVaultName = '${appName}-kv-${uniqueSuffix}'
var containerRegistryName = '${appName}acr${uniqueSuffix}'
var containerAppEnvName = '${appName}-env-${environmentName}'
var containerAppName = '${appName}-app-${environmentName}'
var logAnalyticsName = '${appName}-logs-${environmentName}'

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
  }
}

// Store secrets in Key Vault
resource azureOpenAIEndpointSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'azure-openai-endpoint'
  properties: {
    value: azureOpenAIEndpoint
  }
}

resource azureOpenAIApiKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'azure-openai-api-key'
  properties: {
    value: azureOpenAIApiKey
  }
}

resource embeddingModelSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'aoai-embed-model'
  properties: {
    value: embeddingModel
  }
}

resource chatModelSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'aoai-chat-model'
  properties: {
    value: chatModel
  }
}

// Container Registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: containerRegistryName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

// Log Analytics Workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Container Apps Environment
resource containerAppEnv 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: containerAppEnvName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

// Managed Identity for Container App
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${appName}-identity-${environmentName}'
  location: location
}

// Grant Key Vault Secrets User role to Managed Identity
resource keyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, managedIdentity.id, 'KeyVaultSecretsUser')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Container App
resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8866
        transport: 'auto'
        allowInsecure: false
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          username: containerRegistry.listCredentials().username
          passwordSecretRef: 'acr-password'
        }
      ]
      secrets: [
        {
          name: 'acr-password'
          value: containerRegistry.listCredentials().passwords[0].value
        }
        {
          name: 'azure-openai-endpoint'
          keyVaultUrl: azureOpenAIEndpointSecret.properties.secretUri
          identity: managedIdentity.id
        }
        {
          name: 'azure-openai-api-key'
          keyVaultUrl: azureOpenAIApiKeySecret.properties.secretUri
          identity: managedIdentity.id
        }
        {
          name: 'aoai-embed-model'
          keyVaultUrl: embeddingModelSecret.properties.secretUri
          identity: managedIdentity.id
        }
        {
          name: 'aoai-chat-model'
          keyVaultUrl: chatModelSecret.properties.secretUri
          identity: managedIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: appName
          image: '${containerRegistry.properties.loginServer}/${appName}:${imageTag}'
          resources: {
            cpu: json('1.0')
            memory: '2Gi'
          }
          env: [
            {
              name: 'AZURE_OPENAI_ENDPOINT'
              secretRef: 'azure-openai-endpoint'
            }
            {
              name: 'AZURE_OPENAI_API_KEY'
              secretRef: 'azure-openai-api-key'
            }
            {
              name: 'AOAI_EMBED_MODEL'
              secretRef: 'aoai-embed-model'
            }
            {
              name: 'AOAI_CHAT_MODEL'
              secretRef: 'aoai-chat-model'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
        rules: [
          {
            name: 'http-scaling'
            http: {
              metadata: {
                concurrentRequests: '50'
              }
            }
          }
        ]
      }
    }
  }
  dependsOn: [
    keyVaultRoleAssignment
  ]
}

// Outputs
output containerAppUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
output containerRegistryLoginServer string = containerRegistry.properties.loginServer
output keyVaultName string = keyVault.name
output managedIdentityClientId string = managedIdentity.properties.clientId
