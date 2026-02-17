# Guide de Déploiement Azure - Vision AI

Ce guide vous accompagne pas à pas pour déployer votre application sur Azure avec un compte **Azure Student**.

## 📋 Prérequis

- ✅ Compte Azure Student actif ([S'inscrire](https://azure.microsoft.com/fr-fr/free/students/))
- ✅ Azure CLI installé ([Télécharger](https://docs.microsoft.com/cli/azure/install-azure-cli))
- ✅ Code du projet prêt

## 🔐 Étape 1 : Connexion à Azure

```powershell
# Se connecter à Azure
az login

# Vérifier votre abonnement
az account show

# Lister vos abonnements (si vous en avez plusieurs)
az account list --output table

# Sélectionner votre abonnement Student
az account set --subscription "Azure for Students"
```

## 🏗️ Étape 2 : Créer le Resource Group

Un Resource Group est un conteneur logique pour toutes vos ressources Azure.

```powershell
# Définir les variables
$RESOURCE_GROUP = "rg-vision-ai"
$LOCATION = "francecentral"  # ou "westeurope"

# Créer le Resource Group
az group create `
  --name $RESOURCE_GROUP `
  --location $LOCATION
```

## 🧠 Étape 3 : Créer Cognitive Services

### Option A : Multi-Service Account (Recommandé)

Un seul compte pour Computer Vision + Face API :

```powershell
$COGNITIVE_NAME = "cog-vision-ai-$(Get-Random -Maximum 9999)"

az cognitiveservices account create `
  --name $COGNITIVE_NAME `
  --resource-group $RESOURCE_GROUP `
  --kind CognitiveServices `
  --sku S0 `
  --location $LOCATION `
  --yes

# Récupérer l'endpoint
$VISION_ENDPOINT = az cognitiveservices account show `
  --name $COGNITIVE_NAME `
  --resource-group $RESOURCE_GROUP `
  --query "properties.endpoint" `
  --output tsv

# Récupérer la clé
$VISION_KEY = az cognitiveservices account keys list `
  --name $COGNITIVE_NAME `
  --resource-group $RESOURCE_GROUP `
  --query "key1" `
  --output tsv

Write-Host "✅ Cognitive Services créé"
Write-Host "Endpoint: $VISION_ENDPOINT"
Write-Host "Key: $VISION_KEY"
```

### Option B : Services séparés

Si vous préférez séparer Computer Vision et Face API :

```powershell
# Computer Vision
$VISION_NAME = "vision-ai-$(Get-Random -Maximum 9999)"

az cognitiveservices account create `
  --name $VISION_NAME `
  --resource-group $RESOURCE_GROUP `
  --kind ComputerVision `
  --sku F0 `
  --location $LOCATION `
  --yes

# Face API
$FACE_NAME = "face-ai-$(Get-Random -Maximum 9999)"

az cognitiveservices account create `
  --name $FACE_NAME `
  --resource-group $RESOURCE_GROUP `
  --kind Face `
  --sku F0 `
  --location $LOCATION `
  --yes
```

> **Note** : Le SKU `F0` est gratuit mais limité. Utilisez `S0` pour plus de transactions.

## 💾 Étape 4 : Créer le Storage Account

```powershell
$STORAGE_NAME = "stvisionai$(Get-Random -Maximum 9999)"

# Créer le Storage Account
az storage account create `
  --name $STORAGE_NAME `
  --resource-group $RESOURCE_GROUP `
  --location $LOCATION `
  --sku Standard_LRS `
  --kind StorageV2

# Récupérer la connection string
$STORAGE_CONNECTION = az storage account show-connection-string `
  --name $STORAGE_NAME `
  --resource-group $RESOURCE_GROUP `
  --query "connectionString" `
  --output tsv

# Créer le conteneur Blob pour les images
az storage container create `
  --name images `
  --account-name $STORAGE_NAME `
  --connection-string $STORAGE_CONNECTION

Write-Host "✅ Storage Account créé"
Write-Host "Connection String: $STORAGE_CONNECTION"
```

## ⚡ Étape 5 : Créer l'Azure Function App

```powershell
$FUNCTION_APP_NAME = "func-vision-ai-$(Get-Random -Maximum 9999)"

# Créer un Storage Account pour l'Azure Function
$FUNC_STORAGE_NAME = "stfunc$(Get-Random -Maximum 9999)"

az storage account create `
  --name $FUNC_STORAGE_NAME `
  --resource-group $RESOURCE_GROUP `
  --location $LOCATION `
  --sku Standard_LRS

# Créer la Function App (Python 3.10)
az functionapp create `
  --name $FUNCTION_APP_NAME `
  --resource-group $RESOURCE_GROUP `
  --storage-account $FUNC_STORAGE_NAME `
  --consumption-plan-location $LOCATION `
  --runtime python `
  --runtime-version 3.10 `
  --functions-version 4 `
  --os-type Linux

Write-Host "✅ Function App créée"
Write-Host "URL: https://$FUNCTION_APP_NAME.azurewebsites.net"

## 📊 Étape 6 : Monitoring (Application Insights)

Le script automatisé configure cela pour vous. Si vous le faites manuellement :
1. Créez un **Workspace Log Analytics**.
2. Créez un composant **Application Insights**.
3. Liez-le à votre **Function App** via l'onglet "Monitoring > App Insights".
```

## 🔧 Étape 6 : Configurer les variables d'environnement

```powershell
# Configurer les Application Settings
az functionapp config appsettings set `
  --name $FUNCTION_APP_NAME `
  --resource-group $RESOURCE_GROUP `
  --settings `
    "VISION_ENDPOINT=$VISION_ENDPOINT" `
    "VISION_KEY=$VISION_KEY" `
    "STORAGE_CONNECTION_STRING=$STORAGE_CONNECTION" `
    "STORAGE_CONTAINER_NAME=images"

# Activer CORS
az functionapp cors add `
  --name $FUNCTION_APP_NAME `
  --resource-group $RESOURCE_GROUP `
  --allowed-origins "*"

Write-Host "✅ Configuration terminée"
```

## 📤 Étape 7 : Déployer le code

### Déployer l'Azure Function

```powershell
cd backend

# Installer Azure Functions Core Tools (si pas déjà fait)
npm install -g azure-functions-core-tools@4

# Déployer
func azure functionapp publish $FUNCTION_APP_NAME

Write-Host "✅ Azure Function déployée"
Write-Host "API URL: https://$FUNCTION_APP_NAME.azurewebsites.net/api/analyze"
```

### Déployer le Frontend

**Option 1 : Azure Static Web Apps (Recommandé)**

```powershell
# Installer SWA CLI
npm install -g @azure/static-web-apps-cli

# Créer une Static Web App
az staticwebapp create `
  --name "swa-vision-ai" `
  --resource-group $RESOURCE_GROUP `
  --location $LOCATION

# Déployer
cd ../frontend
swa deploy --app-location . --deployment-token <TOKEN>
```

**Option 2 : Blob Storage Static Website**

```powershell
# Activer le site web statique
az storage blob service-properties update `
  --account-name $STORAGE_NAME `
  --static-website `
  --index-document index.html `
  --404-document index.html

# Uploader les fichiers
cd ../frontend

# Mettre à jour l'URL de l'API dans app.js
# Remplacer: AZURE_FUNCTION_URL: 'http://localhost:7071/api/analyze'
# Par: AZURE_FUNCTION_URL: 'https://$FUNCTION_APP_NAME.azurewebsites.net/api/analyze'

# Uploader vers Blob Storage
az storage blob upload-batch `
  --account-name $STORAGE_NAME `
  --source . `
  --destination '$web' `
  --connection-string $STORAGE_CONNECTION

# Récupérer l'URL du site
$WEBSITE_URL = az storage account show `
  --name $STORAGE_NAME `
  --resource-group $RESOURCE_GROUP `
  --query "primaryEndpoints.web" `
  --output tsv

Write-Host "✅ Frontend déployé"
Write-Host "URL: $WEBSITE_URL"
```

## 🎯 Étape 8 : Tester l'application

1. Ouvrez l'URL de votre frontend
2. Uploadez une image
3. Vérifiez les résultats

### Vérifier les logs Azure Function

```powershell
# Voir les logs en temps réel
az webapp log tail `
  --name $FUNCTION_APP_NAME `
  --resource-group $RESOURCE_GROUP
```

## 📊 Étape 9 : Surveiller les coûts

```powershell
# Voir la consommation actuelle
az consumption usage list `
  --start-date "2026-02-01" `
  --end-date "2026-02-28" `
  --output table
```

## 🧹 Nettoyage (Supprimer toutes les ressources)

```powershell
# ⚠️ ATTENTION : Cela supprime TOUT le Resource Group
az group delete `
  --name $RESOURCE_GROUP `
  --yes `
  --no-wait
```

## 📝 Résumé des URLs importantes

Après le déploiement, notez ces URLs :

| Service | URL |
|---------|-----|
| **Azure Function** | `https://<function-app-name>.azurewebsites.net/api/analyze` |
| **Frontend** | `https://<storage-account>.z16.web.core.windows.net/` |
| **Portail Azure** | `https://portal.azure.com` |

## 🔍 Dépannage

### Erreur : "Subscription not found"

```powershell
az account list --output table
az account set --subscription "Azure for Students"
```

### Erreur : "Location not available"

Changez la région :

```powershell
$LOCATION = "westeurope"  # ou "northeurope", "uksouth"
```

### Erreur : "Face API not available"

Face API n'est pas disponible dans toutes les régions. Utilisez :
- `francecentral`
- `westeurope`
- `eastus`

### Vérifier les quotas

```powershell
az cognitiveservices account list-usage `
  --name $COGNITIVE_NAME `
  --resource-group $RESOURCE_GROUP
```

## 🎓 Ressources supplémentaires

- [Documentation Azure Functions](https://docs.microsoft.com/azure/azure-functions/)
- [Documentation Cognitive Services](https://docs.microsoft.com/azure/cognitive-services/)
- [Azure Student Portal](https://portal.azure.com/#blade/Microsoft_Azure_Education/EducationMenuBlade/overview)

---

**Besoin d'aide ?** Consultez les logs Azure ou contactez le support Azure Student.
