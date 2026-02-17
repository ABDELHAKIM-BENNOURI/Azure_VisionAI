# ========================================
# Script PowerShell pour créer automatiquement
# toutes les ressources Azure nécessaires
# ========================================

# Forcer l'encodage UTF8 pour l'affichage console
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Configurer Azure CLI pour installer les extensions automatiquement
az config set extension.use_dynamic_install=yes_without_prompt | Out-Null
az config set extension.dynamic_install_allow_preview=true | Out-Null

Write-Host "[INFO] Configuration automatique des ressources Azure" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# Vérifier si Azure CLI est installé
try {
  az --version | Out-Null
}
catch {
  Write-Host "[ERREUR] Azure CLI n'est pas installé" -ForegroundColor Red
  Write-Host "Téléchargez-le ici: https://docs.microsoft.com/cli/azure/install-azure-cli" -ForegroundColor Yellow
  exit 1
}

# Se connecter à Azure
Write-Host "[CONNEXION] Connexion à Azure..." -ForegroundColor Yellow
az login

# Demander les informations
Write-Host ""
Write-Host "[PROJET] Configuration du projet" -ForegroundColor Cyan
$RESOURCE_GROUP = Read-Host "Nom du Resource Group (défaut: rg-vision-ai)"
if ([string]::IsNullOrWhiteSpace($RESOURCE_GROUP)) { $RESOURCE_GROUP = "rg-vision-ai" }

$LOCATION = Read-Host "Région Azure (défaut: francecentral)"
if ([string]::IsNullOrWhiteSpace($LOCATION)) { $LOCATION = "francecentral" }

Write-Host ""
Write-Host "[CONFIG] Configuration:" -ForegroundColor Green
Write-Host "   Resource Group: $RESOURCE_GROUP"
Write-Host "   Location: $LOCATION"
Write-Host ""

$confirm = Read-Host "Continuer? (O/n)"
if ($confirm -eq "n") {
  Write-Host "[ANNULÉ] Opération annulée" -ForegroundColor Red
  exit 0
}

# Générer des noms uniques
$RANDOM_SUFFIX = Get-Random -Maximum 9999
$COGNITIVE_NAME = "cog-vision-ai-$RANDOM_SUFFIX"
$STORAGE_NAME = "stvisionai$RANDOM_SUFFIX"
$FUNC_STORAGE_NAME = "stfunc$RANDOM_SUFFIX"
$FUNCTION_APP_NAME = "func-vision-ai-$RANDOM_SUFFIX"

Write-Host ""
Write-Host "[CREATION] Création des ressources..." -ForegroundColor Cyan

# 1. Créer le Resource Group
Write-Host ""
Write-Host "1. Création du Resource Group..." -ForegroundColor Yellow
az group create --name $RESOURCE_GROUP --location $LOCATION | Out-Null
Write-Host "   [OK] Resource Group créé" -ForegroundColor Green

# 2. Créer Cognitive Services
Write-Host ""
Write-Host "2. Création de Cognitive Services..." -ForegroundColor Yellow
az cognitiveservices account create `
  --name $COGNITIVE_NAME `
  --resource-group $RESOURCE_GROUP `
  --kind CognitiveServices `
  --sku S0 `
  --location $LOCATION `
  --yes | Out-Null

$VISION_ENDPOINT = az cognitiveservices account show `
  --name $COGNITIVE_NAME `
  --resource-group $RESOURCE_GROUP `
  --query "properties.endpoint" `
  --output tsv

$VISION_KEY = az cognitiveservices account keys list `
  --name $COGNITIVE_NAME `
  --resource-group $RESOURCE_GROUP `
  --query "key1" `
  --output tsv

Write-Host "   [OK] Cognitive Services créé" -ForegroundColor Green

# 3. Créer Storage Account
Write-Host ""
Write-Host "3. Création du Storage Account..." -ForegroundColor Yellow
az storage account create `
  --name $STORAGE_NAME `
  --resource-group $RESOURCE_GROUP `
  --location $LOCATION `
  --sku Standard_LRS `
  --kind StorageV2 | Out-Null

$STORAGE_CONNECTION = az storage account show-connection-string `
  --name $STORAGE_NAME `
  --resource-group $RESOURCE_GROUP `
  --query "connectionString" `
  --output tsv

# Créer le conteneur Blob
az storage container create `
  --name images `
  --account-name $STORAGE_NAME `
  --connection-string $STORAGE_CONNECTION | Out-Null

Write-Host "   [OK] Storage Account créé" -ForegroundColor Green

# 4. Créer Function App Storage
Write-Host ""
Write-Host "4. Création du Storage pour Function App..." -ForegroundColor Yellow
az storage account create `
  --name $FUNC_STORAGE_NAME `
  --resource-group $RESOURCE_GROUP `
  --location $LOCATION `
  --sku Standard_LRS | Out-Null

Write-Host "   [OK] Storage créé" -ForegroundColor Green

# 5. Créer l'Espace de Travail Log Analytics (requis pour App Insights)
Write-Host ""
Write-Host "5. Création du Workspace Log Analytics..." -ForegroundColor Yellow
$LOG_WORKSPACE_NAME = "log-vision-ai-$RANDOM_SUFFIX"
az monitor log-analytics workspace create `
  --resource-group $RESOURCE_GROUP `
  --workspace-name $LOG_WORKSPACE_NAME `
  --location $LOCATION | Out-Null

# 6. Créer Application Insights
Write-Host ""
Write-Host "6. Création d'Application Insights..." -ForegroundColor Yellow
$APP_INSIGHTS_NAME = "appi-vision-ai-$RANDOM_SUFFIX"
az monitor app-insights component create `
  --app $APP_INSIGHTS_NAME `
  --location $LOCATION `
  --resource-group $RESOURCE_GROUP `
  --workspace $LOG_WORKSPACE_NAME `
  --kind web `
  --application-type web | Out-Null

$APP_INSIGHTS_KEY = az monitor app-insights component show --app $APP_INSIGHTS_NAME --resource-group $RESOURCE_GROUP --query "instrumentationKey" --output tsv
$APP_INSIGHTS_CONNECTION = az monitor app-insights component show --app $APP_INSIGHTS_NAME --resource-group $RESOURCE_GROUP --query "connectionString" --output tsv

Write-Host "   [OK] Application Insights créé" -ForegroundColor Green

# 7. Créer Function App
Write-Host ""
Write-Host "7. Création de l'Azure Function App..." -ForegroundColor Yellow
az functionapp create `
  --name $FUNCTION_APP_NAME `
  --resource-group $RESOURCE_GROUP `
  --storage-account $FUNC_STORAGE_NAME `
  --consumption-plan-location $LOCATION `
  --runtime python `
  --runtime-version 3.10 `
  --functions-version 4 `
  --app-insights $APP_INSIGHTS_NAME `
  --os-type Linux | Out-Null

Write-Host "   [OK] Function App créée" -ForegroundColor Green

# 8. Configurer les variables d'environnement
Write-Host ""
Write-Host "8. Configuration des variables d'environnement..." -ForegroundColor Yellow
az functionapp config appsettings set `
  --name $FUNCTION_APP_NAME `
  --resource-group $RESOURCE_GROUP `
  --settings `
  "VISION_ENDPOINT=$VISION_ENDPOINT" `
  "VISION_KEY=$VISION_KEY" `
  "STORAGE_CONNECTION_STRING=$STORAGE_CONNECTION" `
  "STORAGE_CONTAINER_NAME=images" | Out-Null

# Activer CORS
az functionapp cors add `
  --name $FUNCTION_APP_NAME `
  --resource-group $RESOURCE_GROUP `
  --allowed-origins "*" | Out-Null

Write-Host "   [OK] Configuration terminée" -ForegroundColor Green

# 9. Créer le fichier local.settings.json
Write-Host ""
Write-Host "9. Création du fichier local.settings.json..." -ForegroundColor Yellow

$localSettings = @"
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "",
    "FUNCTIONS_WORKER_RUNTIME": "python",
    "VISION_ENDPOINT": "$VISION_ENDPOINT",
    "VISION_KEY": "$VISION_KEY",
    "STORAGE_CONNECTION_STRING": "$STORAGE_CONNECTION",
    "STORAGE_CONTAINER_NAME": "images",
    "APPINSIGHTS_INSTRUMENTATIONKEY": "$APP_INSIGHTS_KEY",
    "APPLICATIONINSIGHTS_CONNECTION_STRING": "$APP_INSIGHTS_CONNECTION"
  },
  "Host": {
    "CORS": "*",
    "CORSCredentials": false
  }
}
"@

$localSettings | Out-File -FilePath ".\backend\local.settings.json" -Encoding UTF8
Write-Host "   [OK] Fichier créé: backend\local.settings.json" -ForegroundColor Green

# 10. Mettre à jour automatiquement frontend/app.js
Write-Host ""
Write-Host "10. Mise à jour automatique du Frontend..." -ForegroundColor Yellow
$APP_JS_PATH = ".\frontend\app.js"
if (Test-Path $APP_JS_PATH) {
  $NEW_URL = "https://$FUNCTION_APP_NAME.azurewebsites.net/api/analyze"
  (Get-Content $APP_JS_PATH) -replace "AZURE_FUNCTION_URL: '.*',?", "AZURE_FUNCTION_URL: '$NEW_URL'," | Set-Content $APP_JS_PATH
  Write-Host "   [OK] Frontend mis à jour: $APP_JS_PATH" -ForegroundColor Green
}
else {
  Write-Host "   [ATTENTION] Fichier non trouvé: $APP_JS_PATH" -ForegroundColor Yellow
}

# 11. Résumé
Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "[SUCCÈS] Configuration terminée avec succès!" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[INFO] Informations importantes:" -ForegroundColor Cyan
Write-Host ""
Write-Host "Resource Group:" -ForegroundColor Yellow
Write-Host "   $RESOURCE_GROUP"
Write-Host ""
Write-Host "Cognitive Services:" -ForegroundColor Yellow
Write-Host "   Nom: $COGNITIVE_NAME"
Write-Host "   Endpoint: $VISION_ENDPOINT"
Write-Host "   Key: $VISION_KEY"
Write-Host ""
Write-Host "Storage Account:" -ForegroundColor Yellow
Write-Host "   Nom: $STORAGE_NAME"
Write-Host "   Conteneur: images"
Write-Host ""
Write-Host "Azure Function:" -ForegroundColor Yellow
Write-Host "   Nom: $FUNCTION_APP_NAME"
Write-Host "   URL: https://$FUNCTION_APP_NAME.azurewebsites.net"
Write-Host "   API: https://$FUNCTION_APP_NAME.azurewebsites.net/api/analyze"
Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[ETAPES] Prochaines étapes:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Déployer l'Azure Function:" -ForegroundColor White
Write-Host "   cd backend"
Write-Host "   func azure functionapp publish $FUNCTION_APP_NAME"
Write-Host ""
Write-Host "2. Mettre à jour frontend/app.js avec l'URL de l'API:" -ForegroundColor White
Write-Host "   AZURE_FUNCTION_URL: 'https://$FUNCTION_APP_NAME.azurewebsites.net/api/analyze'"
Write-Host ""
Write-Host "3. Tester l'application localement:" -ForegroundColor White
Write-Host "   cd backend"
Write-Host "   .venv\Scripts\Activate.ps1"
Write-Host "   func start"
Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# Sauvegarder les informations dans un fichier
$configInfo = @"
# Configuration Azure - Vision AI
Créé le: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Resource Group
Nom: $RESOURCE_GROUP
Location: $LOCATION

## Cognitive Services
Nom: $COGNITIVE_NAME
Endpoint: $VISION_ENDPOINT
Key: $VISION_KEY

## Storage Account
Nom: $STORAGE_NAME
Connection String: $STORAGE_CONNECTION
Conteneur: images

## Azure Function
Nom: $FUNCTION_APP_NAME
URL: https://$FUNCTION_APP_NAME.azurewebsites.net
API Endpoint: https://$FUNCTION_APP_NAME.azurewebsites.net/api/analyze

## Monitoring
Instrumentation Key: $APP_INSIGHTS_KEY
Connection String: $APP_INSIGHTS_CONNECTION

## Commandes utiles

### Déployer la Function
cd backend
func azure functionapp publish $FUNCTION_APP_NAME

### Voir les logs
az webapp log tail --name $FUNCTION_APP_NAME --resource-group $RESOURCE_GROUP

### Supprimer toutes les ressources
az group delete --name $RESOURCE_GROUP --yes --no-wait
"@

$configInfo | Out-File -FilePath ".\azure-config.txt" -Encoding UTF8
Write-Host "[SAUVEGARDE] Configuration sauvegardée dans: azure-config.txt" -ForegroundColor Green
Write-Host ""
