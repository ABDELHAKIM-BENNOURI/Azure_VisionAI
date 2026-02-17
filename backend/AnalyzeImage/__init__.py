import logging
import json
import os
import io
from datetime import datetime
import azure.functions as func
from azure.storage.blob import BlobServiceClient
from azure.cognitiveservices.vision.computervision import ComputerVisionClient
from azure.cognitiveservices.vision.face import FaceClient
from msrest.authentication import CognitiveServicesCredentials


def main(req: func.HttpRequest) -> func.HttpResponse:
    """
    Azure Function pour analyser une image avec Azure Cognitive Services
    - Détection de visages (âge, émotions)
    - Détection d'objets
    - Description automatique en français
    """
    logging.info('Fonction AnalyzeImage démarrée')

    # Gestion CORS pour OPTIONS preflight
    if req.method == 'OPTIONS':
        return func.HttpResponse(
            status_code=200,
            headers={
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type'
            }
        )

    try:
        # Récupération de l'image depuis la requête
        image_file = req.files.get('image')
        
        if not image_file:
            return func.HttpResponse(
                json.dumps({"error": "Aucune image fournie"}),
                status_code=400,
                mimetype="application/json",
                headers={'Access-Control-Allow-Origin': '*'}
            )

        # Lecture du contenu de l'image
        image_data = image_file.read()
        image_stream = io.BytesIO(image_data)
        
        # Configuration des clients Azure
        vision_endpoint = os.environ.get("VISION_ENDPOINT")
        vision_key = os.environ.get("VISION_KEY")
        storage_connection = os.environ.get("STORAGE_CONNECTION_STRING")
        container_name = os.environ.get("STORAGE_CONTAINER_NAME", "images")

        if not all([vision_endpoint, vision_key]):
            return func.HttpResponse(
                json.dumps({"error": "Configuration Azure manquante (Endpoint/Key)"}),
                status_code=500,
                mimetype="application/json",
                headers={'Access-Control-Allow-Origin': '*'}
            )

        # Taille de l'image (max 4MB pour Face API Free)
        image_size_kb = len(image_data) / 1024
        logging.info(f"Traitement d'une image de {image_size_kb:.1f} KB")

        # 1. Upload de l'image vers Blob Storage
        blob_url = None
        if storage_connection:
            try:
                blob_service_client = BlobServiceClient.from_connection_string(storage_connection)
                blob_name = f"upload_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{image_file.filename}"
                blob_client = blob_service_client.get_blob_client(container=container_name, blob=blob_name)
                blob_client.upload_blob(image_data, overwrite=True)
                blob_url = blob_client.url
                logging.info(f"Image uploadée: {blob_url}")
            except Exception as e:
                logging.warning(f"Erreur upload Blob Storage: {str(e)}")

        # Clients Azure
        from azure.ai.vision.imageanalysis import ImageAnalysisClient
        from azure.ai.vision.imageanalysis.models import VisualFeatures
        from azure.core.credentials import AzureKeyCredential

        # Vision 4.0 (Florence Engine)
        vision_client_v4 = ImageAnalysisClient(
            endpoint=vision_endpoint, 
            credential=AzureKeyCredential(vision_key)
        )
        
        # 2. Analyse de l'image (v4.0 - Beaucoup plus précise)
        logging.info("Analyse Vision API 4.0 (Florence)...")
        
        try:
            analysis = vision_client_v4.analyze(
                image_data=image_data,
                visual_features=[
                    VisualFeatures.CAPTION,
                    VisualFeatures.TAGS,
                    VisualFeatures.OBJECTS,
                    VisualFeatures.PEOPLE,
                    VisualFeatures.READ # OCR
                ]
            )
        except Exception as e:
            logging.error(f"Erreur Vision API 4.0: {str(e)}")
            # Fallback legacy if needed (but v4.0 is preferred)
            raise e

        # 3. Détection de visages et de personnes
        faces_data = []
        
        # A. Face API (Visages détaillés)
        try:
            logging.info("Détection Face API (Émotions)...")
            face_client = FaceClient(vision_endpoint, CognitiveServicesCredentials(vision_key))
            
            with io.BytesIO(image_data) as face_stream:
                detected_faces = face_client.face.detect_with_stream(
                    face_stream,
                    return_face_attributes=['age', 'gender', 'emotion', 'smile', 'glasses']
                )

            for face in detected_faces:
                face_data = {
                    "age": round(face.face_attributes.age),
                    "gender": "Homme" if face.face_attributes.gender == "male" else "Femme",
                    "emotions": {
                        "joie": round(face.face_attributes.emotion.happiness * 100, 1),
                        # ... (rest of emotions)
                        "tristesse": round(face.face_attributes.emotion.sadness * 100, 1),
                        "colère": round(face.face_attributes.emotion.anger * 100, 1),
                        "surprise": round(face.face_attributes.emotion.surprise * 100, 1),
                        "peur": round(face.face_attributes.emotion.fear * 100, 1),
                        "dégoût": round(face.face_attributes.emotion.disgust * 100, 1),
                        "neutre": round(face.face_attributes.emotion.neutral * 100, 1)
                    },
                    "sourire": round(face.face_attributes.smile * 100, 1),
                    "lunettes": face.face_attributes.glasses.value if face.face_attributes.glasses else "Aucune",
                    "position": {
                        "x": face.face_rectangle.left,
                        "y": face.face_rectangle.top,
                        "width": face.face_rectangle.width,
                        "height": face.face_rectangle.height
                    }
                }
                faces_data.append(face_data)
            logging.info(f"{len(faces_data)} visage(s) détecté(s) par Face API")
        except Exception as e:
            logging.warning(f"Erreur Face API: {str(e)}")

        # B. People detection (Vision 4.0) - Complément ou Fallback
        try:
            if hasattr(analysis, 'people') and analysis.people:
                for person in analysis.people.list:
                    # FILTRE 1: Seuil de confiance (éviter les détections sur les murs/ombres)
                    if person.confidence < 0.50:
                        continue
                        
                    p_box = person.bounding_box
                    is_duplicate = False
                    
                    # FILTRE 2: Déduplication (vérifier si person est déjà couvert par Face API)
                    for existing_face in faces_data:
                        f_box = existing_face["position"]
                        # Intersection over Union (IOU) simplifiée (si le visage est dans le rectangle de la personne)
                        if (p_box.x <= f_box["x"] <= p_box.x + p_box.width and
                            p_box.y <= f_box["y"] <= p_box.y + p_box.height):
                            is_duplicate = True
                            break
                    
                    if not is_duplicate:
                        faces_data.append({
                            "age": "N/A",
                            "gender": "Inconnu",
                            "position": {
                                "x": p_box.x,
                                "y": p_box.y,
                                "width": p_box.width,
                                "height": p_box.height
                            }
                        })
                logging.info(f"{len(faces_data)} total visages/personnes après déduplication")
        except Exception as e:
            logging.error(f"Erreur lors du post-traitement des personnes: {str(e)}")

        # 4. Extraction du texte (OCR - READ v4.0)
        ocr_data = []
        if analysis.read and analysis.read.blocks:
            for block in analysis.read.blocks:
                for line in block.lines:
                    ocr_data.append({
                        "texte": line.text,
                        "confiance": round(line.words[0].confidence * 100, 1) if line.words else 0,
                        "position": {
                            "x": min(p.x for p in line.bounding_polygon),
                            "y": min(p.y for p in line.bounding_polygon),
                            "width": max(p.x for p in line.bounding_polygon) - min(p.x for p in line.bounding_polygon),
                            "height": max(p.y for p in line.bounding_polygon) - min(p.y for p in line.bounding_polygon)
                        }
                    })
            logging.info(f"Texte détecté: {len(ocr_data)} lignes")

        # 5. Extraction des objets détectés (v4.0)
        objects_data = []
        if analysis.objects and analysis.objects.list:
            for obj in analysis.objects.list:
                label = obj.tags[0].name if obj.tags else "Objet"
                objects_data.append({
                    "nom": label,
                    "confiance": round(obj.tags[0].confidence * 100, 1) if obj.tags else 0,
                    "position": {
                        "x": obj.bounding_box.x,
                        "y": obj.bounding_box.y,
                        "width": obj.bounding_box.width,
                        "height": obj.bounding_box.height
                    }
                })

        # 6. Extraction de la description (Caption v4.0)
        description_text = ""
        if analysis.caption:
            description_text = analysis.caption.text
        
        # 7. Extraction des tags (v4.0)
        tags_data = []
        if analysis.tags and analysis.tags.list:
            tags_data = [
                {"nom": tag.name, "confiance": round(tag.confidence * 100, 1)}
                for tag in analysis.tags.list[:10]
            ]

        # 8. Couleurs dominantes
        # Note: Vision 4.0 simplifié
        colors_data = {
            "dominante": "Automatique",
            "accent": "764ba2"
        }

        # Construction de la réponse JSON
        result = {
            "success": True,
            "timestamp": datetime.now().isoformat(),
            "blob_url": blob_url,
            "analysis": {
                "description": description_text,
                "faces": {
                    "count": len(faces_data),
                    "details": faces_data
                },
                "objects": {
                    "count": len(objects_data),
                    "details": objects_data
                },
                "ocr": {
                    "count": len(ocr_data),
                    "details": ocr_data
                },
                "tags": tags_data,
                "colors": colors_data
            }
        }

        logging.info("Analyse terminée avec succès")

        return func.HttpResponse(
            json.dumps(result, ensure_ascii=False),
            status_code=200,
            mimetype="application/json",
            headers={
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type'
            }
        )

    except Exception as e:
        logging.error(f"Erreur lors de l'analyse: {str(e)}")
        return func.HttpResponse(
            json.dumps({
                "success": False,
                "error": str(e)
            }),
            status_code=500,
            mimetype="application/json",
            headers={'Access-Control-Allow-Origin': '*'}
        )
