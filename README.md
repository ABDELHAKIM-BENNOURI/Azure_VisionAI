# Azure Vision AI - Intelligent Image Analysis

![Azure](https://img.shields.io/badge/Azure-Cognitive%20Services-0078D4?style=for-the-badge&logo=microsoft-azure)
![Python](https://img.shields.io/badge/Python-3.10+-3776AB?style=for-the-badge&logo=python)
![JavaScript](https://img.shields.io/badge/JavaScript-ES6+-F7DF1E?style=for-the-badge&logo=javascript)

Intelligent Cloud application using **Azure Cognitive Services** to analyze images and provide:
- 👤 **Face Detection** (age, emotions, gender)
- 🎯 **Object Detection** with visualization (Bounding Boxes)
- 📝 **OCR (Text Recognition)**: Intelligent text extraction
- 📊 **Real-Time Dashboard**: Session statistics (Analyses, Faces, Objects)
- 📝 **Automatic Description** in French (Florence 4.0 engine)
- 🏷️ **Tags** and dominant colors

## 📋 Table of Contents

- [Architecture](#architecture)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Local Installation](#local-installation)
- [Cloud Deployment (Azure)](#cloud-deployment-azure)
- [Azure Configuration](#azure-configuration)
- [Deployment](#deployment)
- [Usage](#usage)
- [Project Structure](#project-structure)

## 🏗️ Architecture

```
┌─────────────────┐
│      User       │
└────────┬────────┘
         │
         ▼
┌─────────────────────────┐
│  Frontend (HTML/CSS/JS) │ ← Modern user interface
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│  Azure Functions        │ ← Serverless API
│  (Python)               │
└────┬────────┬────────┬──┘
     │        │        │
     ▼        ▼        ▼
┌──────────┐ ┌──────────┐ ┌──────────────┐
│ Blob     │ │ AI Vision│ │ Application  │
│ Storage  │ │ + Face   │ │ Insights     │
└──────────┘ └──────────┘ └──────────────┘
```

## ✨ Features

### 🎨 User Interface
- Modern design with **glassmorphism**
- **Interactive Dashboard**: Track session statistics
- **AI Visualization**: Drawing bounding boxes on the image
- Upload via **drag & drop** or selection
- Image preview
- **JSON Export**: Save analysis results
- Smooth animations & Responsive design

### 🤖 AI Analysis
- **Face Detection**:
  - Estimated age
  - Gender
  - Emotions (happiness, sadness, anger, surprise, fear, disgust, neutral)
  - Smile
  - Glasses
  - Face position

- **Object Detection**:
  - Object identification
  - Confidence score
  - Position in the image

- **OCR (Optical Character Recognition)**:
  - Text extraction from images (signs, documents)
  - Confidence score per text line

- **General Analysis**:
  - Automatic description in French (Florence 4.0 Engine)
  - Relevant tags
  - Dominant colors

## 📦 Prerequisites

### Required Software
- **Python 3.10+** ([Download](https://www.python.org/downloads/))
- **Node.js 18+** (optional, for Azure Functions Core Tools)
- **Git** ([Download](https://git-scm.com/))
- **Azure Student Account** ([Sign up](https://azure.microsoft.com/en-us/free/students/))

### Necessary Azure Resources
- Azure Cognitive Services (Computer Vision + Face API)
- Azure Storage Account (Blob Storage)
- Azure Functions (for deployment)
- Azure Application Insights (Monitoring)

## 🚀 Local Installation

### 1. Clone the project

```powershell
git clone <your-repo>
cd Azure_VisionAI
```

### 2. Backend Configuration

```powershell
cd backend

# Create a Python virtual environment
python -m venv .venv

# Activate the virtual environment
.venv\Scripts\Activate.ps1

# Install dependencies
pip install -r requirements.txt
```

### 3. Environment Variables Configuration

Copy the template file and configure your Azure credentials:

```powershell
cp local.settings.json.template local.settings.json
```

Edit `local.settings.json` with your Azure credentials:

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "",
    "FUNCTIONS_WORKER_RUNTIME": "python",
    "VISION_ENDPOINT": "https://YOUR_REGION.api.cognitive.microsoft.com/",
    "VISION_KEY": "YOUR_VISION_API_KEY",
    "STORAGE_CONNECTION_STRING": "YOUR_STORAGE_CONNECTION_STRING",
    "STORAGE_CONTAINER_NAME": "images"
  },
  "Host": {
    "CORS": "*"
  }
}
```

> [!CAUTION]
> **Key Security**: As a security measure, `VISION_KEY` and `VISION_ENDPOINT` are **never** hardcoded in the codebase. They are managed via this local file and through *App Settings* on Azure.

### 4. Run Azure Functions locally

**Option A: Without Azure Functions Core Tools**

You can test directly with Python:

```powershell
# From the backend folder
python -m azure.functions.worker
```

**Option B: With Azure Functions Core Tools (recommended)**

```powershell
# Install Azure Functions Core Tools
npm install -g azure-functions-core-tools@4

# Start the function
func start
```

The API will be available at: `http://localhost:7071/api/analyze`

### 5. Launch the Frontend

Simply open `frontend/index.html` in your browser.

> **Note**: To avoid CORS issues locally, use a simple HTTP server:

```powershell
cd frontend

# With Python
python -m http.server 8000

# Or with Node.js
npx http-server -p 8000
```

Access at: `http://localhost:8000`

## 🚀 Cloud Deployment (Azure)

To deploy this project to your Azure Student account without errors, we have prepared a step-by-step simplified guide:

👉 **[Consult the Ultimate Deployment Guide (GUIDE.md)](GUIDE.md)**

This guide covers:
- Tool installation (Azure CLI, Functions Core Tools)
- Automatic resource creation via script
- Monitoring with Application Insights

## ☁️ Azure Configuration

Consult the detailed guide: **[DEPLOYMENT.md](DEPLOYMENT.md)**

### Quick Summary

1. **Create a Resource Group**
2. **Create Cognitive Services** (Computer Vision + Face API)
3. **Create a Storage Account** with Blob container
4. **Create a Function App**
5. **Configure environment variables**
6. **Deploy the code**

### Automated Script

Use the PowerShell script to create all resources:

```powershell
.\scripts\setup-azure-resources.ps1
```

## 📤 Deployment

### Azure Function Deployment

```powershell
cd backend

# Deploy to Azure
func azure functionapp publish <your-function-app-name>
```

### Frontend Deployment

**Option 1: Azure Static Web Apps**

```powershell
# Install Azure Static Web Apps CLI
npm install -g @azure/static-web-apps-cli

# Deploy
cd frontend
swa deploy
```

**Option 2: Azure Blob Storage (Static Website)**

```powershell
# Enable static website on your Storage Account
az storage blob service-properties update --account-name <storage-name> --static-website --index-document index.html

# Upload files
az storage blob upload-batch -s ./frontend -d '$web' --account-name <storage-name>
```

## 🎯 Usage

1. **Open the application** in your browser
2. **Select or drag an image**
3. **Click "Analyze"**
4. **View results**:
   - Automatic description
   - Detected faces with emotions
   - Identified objects
   - Tags and colors

### Sample images to test

- Portrait photo (for face detection)
- Group photo (for multiple faces)
- Object photo (for object detection)
- Landscape (for description and tags)

## 📁 Project Structure

```
Azure_VisionAI/
│
├── frontend/                   # User Interface (Web)
│   ├── index.html             # Main application page
│   ├── style.css              # UI styles (Glassmorphism design)
│   └── app.js                 # Frontend logic and API calls
│
├── backend/                    # Serverless Backend (Azure Functions)
│   ├── AnalyzeImage/           # AI analysis logic
│   │   ├── __init__.py        # Python entry point for the API
│   │   └── function.json      # Azure Function trigger configuration
│   ├── requirements.txt       # Python library dependencies
│   ├── host.json              # Global Azure Functions settings
│   └── local.settings.json.template # Config template for local dev
│
├── scripts/                    # Automation Scripts
│   ├── setup-azure-resources.ps1 # Auto-creation of Azure infrastructure
│   └── deploy.ps1              # Deployment automation script
│
├── .env.template               # Template for backend environment variables
├── .gitignore                  # Files excluded from Git tracking
├── DEPLOYMENT.md               # Technical overview of cloud architecture
├── GUIDE.md                    # Step-by-step deployment tutorial
├── LICENSE                     # MIT License (Abdelhakim BENNOURI)
├── README.md                   # Project documentation
└── azure-config.txt            # Your specific Azure resource details
```

## 🔧 Troubleshooting

### Issue: CORS Error

**Solution**: Ensure CORS is enabled in `local.settings.json`:

```json
"Host": {
  "CORS": "*"
}
```

### Issue: Azure Function doesn't start

**Solution**: Check that:
- Python 3.10+ is installed
- Virtual environment is activated
- All dependencies are installed

### Issue: "Missing Azure Configuration" Error

**Solution**: Ensure `local.settings.json` contains:
- `VISION_ENDPOINT`
- `VISION_KEY`

### Issue: Face API not working

**Solution**: Ensure you have enabled **Face API** in Azure Cognitive Services (separate resource or multi-service).

## 📊 Azure Costs (Student)

With an **Azure Student** account ($100 credit):

| Service | Free Tier | Estimated Monthly Cost |
|---------|-----------|------------------------|
| Computer Vision | 5,000 transactions/month | **Free** |
| Face API | 30,000 transactions/month | **Free** |
| Blob Storage | 5 GB | **~$0.01** |
| Azure Functions | 1M executions/month | **Free** |

**Estimated Total: < $1/month** for testing/development usage

## 🤝 Contribution

Contributions are welcome! Feel free to:
- Report bugs
- Suggest improvements
- Add new features

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgements

- **Microsoft Azure** for Cloud services
- **Azure Cognitive Services** for pre-trained AI
- **Google Fonts** for Inter typography

---

**Developed by Abdelhakim Bennouri**
