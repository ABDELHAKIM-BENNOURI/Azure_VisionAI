/**
 * Azure Vision AI - Logic Frontend
 * ========================================
 */
const CONFIG = {
    // URL de votre Azure Function
    AZURE_FUNCTION_URL: 'https://func-vision-ai-3534.azurewebsites.net/api/analyze',
};

// ========================================
// Initialisation
// ========================================
document.addEventListener('DOMContentLoaded', () => {
    // Éléments DOM
    const uploadArea = document.getElementById('uploadArea');
    const fileInput = document.getElementById('fileInput');
    const selectBtn = document.getElementById('selectBtn');
    const imagePreview = document.getElementById('imagePreview');
    const previewImg = document.getElementById('previewImg');
    const analyzeBtn = document.getElementById('analyzeBtn');
    const changeBtn = document.getElementById('changeBtn');
    const loading = document.getElementById('loading');
    const resultsSection = document.getElementById('resultsSection');

    // Éléments de résultats
    const descriptionText = document.getElementById('descriptionText');
    const facesCount = document.getElementById('facesCount');
    const facesContainer = document.getElementById('facesContainer');
    const objectsCount = document.getElementById('objectsCount');
    const objectsContainer = document.getElementById('objectsContainer');
    const tagsContainer = document.getElementById('tagsContainer');
    const colorsContainer = document.getElementById('colorsContainer');

    // Nouveaux éléments (Améliorations)
    const overlayCanvas = document.getElementById('overlayCanvas');
    const ocrCard = document.getElementById('ocrCard');
    const ocrCount = document.getElementById('ocrCount');
    const ocrContainer = document.getElementById('ocrContainer');
    const dashboard = document.getElementById('dashboard');
    const statAnalyses = document.getElementById('statAnalyses');
    const statFaces = document.getElementById('statFaces');
    const statObjects = document.getElementById('statObjects');
    const exportBtn = document.getElementById('exportBtn');

    let selectedFile = null;
    let lastAnalysisResult = null;
    let totalAnalyses = 0;

    // --- Sélection de fichier ---
    selectBtn.addEventListener('click', () => fileInput.click());
    uploadArea.addEventListener('click', () => fileInput.click());

    fileInput.addEventListener('change', (e) => {
        if (e.target.files.length > 0) {
            handleFile(e.target.files[0]);
        }
    });

    // --- Drag & Drop ---
    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
        uploadArea.addEventListener(eventName, (e) => {
            e.preventDefault();
            e.stopPropagation();
        }, false);
    });

    ['dragenter', 'dragover'].forEach(eventName => {
        uploadArea.addEventListener(eventName, () => {
            uploadArea.classList.add('drag-over');
        }, false);
    });

    ['dragleave', 'drop'].forEach(eventName => {
        uploadArea.addEventListener(eventName, () => {
            uploadArea.classList.remove('drag-over');
        }, false);
    });

    uploadArea.addEventListener('drop', (e) => {
        const dt = e.dataTransfer;
        const file = dt.files[0];
        if (file) handleFile(file);
    }, false);
    // --- Traitement du fichier ---
    function handleFile(file) {
        if (!file.type.startsWith('image/')) {
            alert('Veuillez sélectionner une image valide.');
            return;
        }

        selectedFile = file;

        const reader = new FileReader();
        reader.onload = (e) => {
            previewImg.src = e.target.result;
            uploadArea.classList.add('hidden');
            imagePreview.classList.remove('hidden');
            resultsSection.classList.add('hidden');

            // Réinitialiser le canvas au chargement d'une nouvelle image
            const ctx = overlayCanvas.getContext('2d');
            ctx.clearRect(0, 0, overlayCanvas.width, overlayCanvas.height);
        };
        reader.readAsDataURL(file);
    }

    // --- Bouton Changer ---
    changeBtn.addEventListener('click', () => {
        selectedFile = null;
        fileInput.value = '';
        uploadArea.classList.remove('hidden');
        imagePreview.classList.add('hidden');
        resultsSection.classList.add('hidden');
        lastAnalysisResult = null;
    });

    // --- Appel API ---
    analyzeBtn.addEventListener('click', async () => {
        if (!selectedFile) return;

        showLoading(true);
        resultsSection.classList.add('hidden');

        const formData = new FormData();
        formData.append('image', selectedFile);

        try {
            const response = await fetch(CONFIG.AZURE_FUNCTION_URL, {
                method: 'POST',
                body: formData
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.error || `Erreur HTTP: ${response.status}`);
            }

            const data = await response.json();
            lastAnalysisResult = data;
            totalAnalyses++;

            displayResults(data.analysis);
            drawBoundingBoxes(data.analysis);
            updateDashboard(data.analysis);

        } catch (error) {
            console.error('Erreur:', error);
            alert(`Erreur lors de l'analyse: ${error.message}`);
        } finally {
            showLoading(false);
        }
    });

    function showLoading(show) {
        loading.classList.toggle('hidden', !show);
        analyzeBtn.disabled = show;
        if (show) resultsSection.classList.add('hidden');
    }

    // --- Dashboard & Stats ---
    function updateDashboard(analysis) {
        dashboard.classList.remove('hidden');
        statAnalyses.textContent = totalAnalyses;
        statFaces.textContent = analysis.faces.count;
        statObjects.textContent = analysis.objects.count;

        // Petit effet d'animation
        [statAnalyses, statFaces, statObjects].forEach(el => {
            el.style.transform = 'scale(1.2)';
            setTimeout(() => el.style.transform = 'scale(1)', 200);
        });
    }

    // --- Tracé des rectangles (Visualisation IA) ---
    function drawBoundingBoxes(analysis) {
        const img = previewImg;
        const canvas = overlayCanvas;
        const ctx = canvas.getContext('2d');

        // Ajuster la taille du canvas à l'image affichée
        canvas.width = img.clientWidth;
        canvas.height = img.clientHeight;

        // Calculer les ratios car l'image peut être redimensionnée par le CSS
        const scaleX = canvas.width / img.naturalWidth;
        const scaleY = canvas.height / img.naturalHeight;

        ctx.clearRect(0, 0, canvas.width, canvas.height);
        ctx.lineWidth = 3;

        // 1. Dessiner les Visages
        analysis.faces.details.forEach((face, index) => {
            const pos = face.position;
            const x = pos.x * scaleX;
            const y = pos.y * scaleY;
            const w = pos.width * scaleX;
            const h = pos.height * scaleY;

            // Rectangle
            ctx.strokeStyle = '#f5576c'; // Rose/Rouge pour visages
            ctx.strokeRect(x, y, w, h);

            // Label
            ctx.fillStyle = '#f5576c';
            ctx.font = 'bold 12px Inter';
            ctx.fillText(`Persona #${index + 1} (${face.age} ans)`, x, y > 10 ? y - 5 : y + 15);
        });

        // 2. Dessiner les Objets
        analysis.objects.details.forEach(obj => {
            const pos = obj.position;
            const x = pos.x * scaleX;
            const y = pos.y * scaleY;
            const w = pos.width * scaleX;
            const h = pos.height * scaleY;

            ctx.strokeStyle = '#4facfe'; // Bleu pour objets
            ctx.setLineDash([5, 3]);
            ctx.strokeRect(x, y, w, h);
            ctx.setLineDash([]); // Reset dash

            ctx.fillStyle = '#4facfe';
            ctx.fillText(`${obj.nom} (${obj.confiance}%)`, x, y > 10 ? y - 5 : y + 15);
        });
    }

    // --- Affichage des résultats ---
    function displayResults(analysis) {
        resultsSection.classList.remove('hidden');

        // 1. Description
        descriptionText.textContent = analysis.description || "Aucune description générée.";

        // 2. OCR (Nouveau)
        ocrContainer.innerHTML = '';
        if (analysis.ocr && analysis.ocr.count > 0) {
            ocrCard.classList.remove('hidden');
            ocrCount.textContent = analysis.ocr.count;
            analysis.ocr.details.forEach(line => {
                const div = document.createElement('div');
                div.className = 'ocr-line';
                div.textContent = line.texte;
                ocrContainer.appendChild(div);
            });
        } else {
            ocrCard.classList.add('hidden');
        }

        // 3. Visages
        facesContainer.innerHTML = '';
        facesCount.textContent = analysis.faces.count;

        if (analysis.faces.count > 0) {
            analysis.faces.details.forEach((face, index) => {
                const faceDiv = document.createElement('div');
                faceDiv.className = 'face-item';

                let topEmotion = "neutre";
                let topScore = 0;
                let emotionEmoji = "😐";

                const emojis = { joie: "😊", tristesse: "😢", colère: "😠", surprise: "😲", peur: "😨", dégoût: "🤢", neutre: "😐" };

                if (face.emotions) {
                    for (const [emo, score] of Object.entries(face.emotions)) {
                        if (score > topScore) {
                            topScore = score;
                            topEmotion = emo;
                            emotionEmoji = emojis[emo] || "😐";
                        }
                    }
                }

                faceDiv.innerHTML = `
                    <div class="face-header">${emotionEmoji} Persona #${index + 1}</div>
                    <div class="face-info">
                        <div class="info-item"><span class="info-label">Âge:</span> <span class="info-value">${face.age} ans</span></div>
                        <div class="info-item"><span class="info-label">Genre:</span> <span class="info-value">${face.gender}</span></div>
                        <div class="info-item"><span class="info-label">Émotion:</span> <span class="info-value">${topEmotion}</span></div>
                    </div>
                `;
                facesContainer.appendChild(faceDiv);
            });
        }

        // 4. Objets
        objectsContainer.innerHTML = '';
        objectsCount.textContent = analysis.objects.count;
        if (analysis.objects.count > 0) {
            analysis.objects.details.forEach(obj => {
                const span = document.createElement('span');
                span.className = 'tag';
                span.style.background = 'rgba(79, 172, 254, 0.1)';
                span.innerHTML = `📦 ${obj.nom} <small>${obj.confiance}%</small>`;
                objectsContainer.appendChild(span);
            });
        }

        // 5. Tags
        tagsContainer.innerHTML = '';
        if (analysis.tags) {
            analysis.tags.forEach(tag => {
                const span = document.createElement('span');
                span.className = 'tag';
                span.innerHTML = `#${tag.nom} <small>${tag.confiance}%</small>`;
                tagsContainer.appendChild(span);
            });
        }

        // 6. Palette
        colorsContainer.innerHTML = '';
        if (analysis.colors) {
            const div = document.createElement('div');
            div.className = 'color-item';
            div.innerHTML = `
                <div class="color-swatch" style="background-color: #${analysis.colors.accent}"></div>
                <div class="color-info">
                    <span class="color-label">Dominante</span>
                    <span class="color-value">#${analysis.colors.accent}</span>
                </div>
            `;
            colorsContainer.appendChild(div);
        }

        resultsSection.scrollIntoView({ behavior: 'smooth' });
    }

    // --- Export JSON ---
    exportBtn.addEventListener('click', () => {
        if (!lastAnalysisResult) return;
        const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(lastAnalysisResult, null, 2));
        const downloadAnchorNode = document.createElement('a');
        downloadAnchorNode.setAttribute("href", dataStr);
        downloadAnchorNode.setAttribute("download", `analysis_${new Date().getTime()}.json`);
        document.body.appendChild(downloadAnchorNode);
        downloadAnchorNode.click();
        downloadAnchorNode.remove();
    });

    // Redessiner les boîtes si la fenêtre change de taille
    window.addEventListener('resize', () => {
        if (lastAnalysisResult) drawBoundingBoxes(lastAnalysisResult.analysis);
    });
});
