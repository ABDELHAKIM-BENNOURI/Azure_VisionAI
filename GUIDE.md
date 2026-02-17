# 🚀 Guide Ultime de Déploiement - Azure Vision AI

Ce guide a été mis à jour pour inclure tous les correctifs nécessaires et les nouvelles fonctionnalités (OCR, Dashboard, Visualisation Canvas et Monitoring App Insights). Suivez ces étapes dans l'ordre pour un contrôle total.

---

## 🛠️ Étape 0 : Nettoyage (Si vous recommencez)

Si vous voulez vraiment repartir de zéro, vous pouvez supprimer le groupe de ressources précédent (facultatif si vous voulez juste recréer avec un autre nom) :
```powershell
az group delete --name rg-vision-ai --yes --no-wait
```

---

## 📦 Étape 1 : Installation des Outils (Préréquis)

Vous avez besoin de **deux outils** sur votre ordinateur :

1. **Azure CLI** : [Télécharger ici](https://aka.ms/installazurecliwindows)
2. **Azure Functions Core Tools** : [Télécharger l'installeur MSI (64-bit)](https://go.microsoft.com/fwlink/?linkid=2174087)

⚠️ **TRÈS IMPORTANT** : Après avoir installé ces deux outils, **REDÉMARREZ votre terminal** (fermez-le et rouvrez-le).

---

## ✅ Étape 2 : Vérification et Connexion

Ouvrez un nouveau terminal PowerShell et vérifiez vos outils :

```powershell
# Vérifier les outils
az --version
func --version

# Se connecter à Azure
az login
```
*Une fenêtre s'ouvrira, connectez-vous avec votre compte Azure Student.*

---

## 📋 Étape 3 : Enregistrement des Services Azure

C'est l'étape cruciale pour éviter les erreurs "MissingSubscriptionRegistration" :

```powershell
# Enregistrer les services nécessaires (Copiez-collez tout d'un coup)
az provider register --namespace Microsoft.CognitiveServices
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.Web

# Vérifier que tout est "Registered" (Attendez 1 minute si besoin)
az provider list --query "[?namespace=='Microsoft.CognitiveServices' || namespace=='Microsoft.Storage' || namespace=='Microsoft.Web'].{Provider:namespace, Status:registrationState}" --output table
```

---

## 🎯 Étape 4 : Création des Ressources (Script Automatique)

Le script va maintenant créer toute votre infrastructure proprement :

```powershell
# Aller dans le dossier du projet
cd "C:\Users\Hakim bn.DESKTOP-LNFAP57\Desktop\Azure_VisionAI"

# Exécuter le script
.\scripts\setup-azure-resources.ps1
```
> [!TIP]
> Répondez aux questions par défaut (Entrée) et tapez 'O' pour confirmer. 
> À la fin, notez bien le **NOM de votre Function App** (ex: `func-vision-ai-1234`).

---

## 📤 Étape 5 : Déploiement du Code Backend

Maintenant que vos outils sont installés, la commande `func` va fonctionner :

```powershell
# 1. Aller dans le dossier backend
cd backend

# 2. Activer votre environnement Python (si pas déjà fait)
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt

# 3. Déployer vers Azure
# REMPLACEZ XXXX par votre numéro de projet affiché par le script
func azure functionapp publish func-vision-ai-XXXX
```

---

## 🎨 Étape 6 : Test du Frontend

### 1. Vérification (Automatique)
Le script a **automatiquement** mis à jour l'URL dans votre fichier `frontend/app.js`. Vous n'avez rien à modifier !

### 2. Lancer le site
Ouvrez `frontend/index.html` dans Chrome ou Edge.
*   **Visualisation** : Voyez les rectangles IA apparaître directement sur l'image.
*   **Dashboard** : Suivez vos statistiques en haut de l'écran.
*   **OCR** : Testez une image avec du texte pour voir l'extraction en direct.

---

## 📊 Étape 7 : Monitoring (Application Insights)

Votre projet est maintenant "sous surveillance" professionnelle :
1. Allez sur le [Portail Azure](https://portal.azure.com).
2. Cherchez votre ressource **Application Insights** (nommée `appi-vision-ai-XXXX`).
3. Regardez le tableau de bord pour voir les erreurs et les temps de réponse de votre IA en temps réel.

---

---

## 🔗 Étape 8 : Se connecter à votre stockage (Azure Storage Explorer)

Pour gérer et voir vos images facilement sans utiliser le navigateur :

1.  **Ouvrez Azure Storage Explorer**.
2.  Cliquez sur l'icône de la **prise électrique** (Connect) dans la barre de gauche.
3.  Choisissez **"Storage account or service"**.
4.  Sélectionnez **"Connection string (Key or SAS)"**.
5.  Donnez-lui un nom (ex: `Stockage Vision IA`).
6.  **Où trouver le code ?** Ouvrez votre fichier `azure-config.txt` à la racine du projet et copiez la ligne qui commence par `DefaultEndpointsProtocol=https...`.
7.  Collez ce code dans la case **"Connection string"** et cliquez sur **Next** puis **Connect**.

📂 **Où sont les images ?**
Dans l'Explorateur, allez dans : `Stockage Vision IA` > `Blob Containers` > `images`. Vous y verrez toutes vos photos avec les dates exactes !

---

## 🔍 Aide et Dépannage

- **Erreur de script** : Si PowerShell refuse de lancer le script, tapez :
  `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`
- **Azure Portal** : Vous pouvez tout surveiller sur [portal.azure.com](https://portal.azure.com).

**Bonne chance pour votre nouveau départ ! Vous maîtrisez maintenant tout le flux. 🚀**
