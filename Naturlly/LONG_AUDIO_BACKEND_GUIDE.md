# 🚀 Guía para Implementar el Servicio de Audio Largo en Google Cloud VM

## 📋 Requisitos Previos

1. **VM en Google Cloud** con Node.js o Python instalado
2. **Cuenta de servicio de Google Cloud** con permisos para:
   - Cloud Text-to-Speech API
   - Cloud Storage (para almacenar archivos de audio)
3. **Bucket de Cloud Storage** creado

## 🛠️ Implementación del Backend

### Opción 1: Node.js con Express

```javascript
const express = require('express');
const { TextToSpeechClient } = require('@google-cloud/text-to-speech');
const { Storage } = require('@google-cloud/storage');

const app = express();
app.use(express.json());

// Configurar clientes de Google Cloud
const ttsClient = new TextToSpeechClient();
const storage = new Storage();
const bucketName = 'tu-bucket-audio'; // Reemplaza con tu bucket

// POST /tts/long/start
app.post('/tts/long/start', async (req, res) => {
  try {
    const { text, languageCode, voiceName, speakingRate, pitch, outputGcsUri } = req.body;

    // Iniciar síntesis larga
    const [operation] = await ttsClient.synthesizeLongAudio({
      input: { text },
      voice: {
        languageCode: languageCode || 'es-ES',
        name: voiceName,
      },
      audioConfig: {
        audioEncoding: 'LINEAR16',
        speakingRate: speakingRate || 1.0,
        pitch: pitch || 0.0,
      },
      outputGcsUri,
    });

    res.json({ operationId: operation.name });
  } catch (error) {
    console.error('Error starting synthesis:', error);
    res.status(500).json({ error: error.message });
  }
});

// GET /tts/long/status
app.get('/tts/long/status', async (req, res) => {
  try {
    const { operationId } = req.query;

    const [operation] = await ttsClient.checkSynthesizeLongAudioProgress(operationId);

    res.json({
      done: operation.done,
      error: operation.error?.message,
      outputGcsUri: operation.metadata?.outputGcsUri,
    });
  } catch (error) {
    console.error('Error checking status:', error);
    res.status(500).json({ error: error.message });
  }
});

// GET /tts/long/download
app.get('/tts/long/download', async (req, res) => {
  try {
    const { path } = req.query;

    // path debería ser como 'gs://bucket/audio/file.wav'
    const filePath = path.replace('gs://', '');
    const [bucket, ...fileParts] = filePath.split('/');
    const fileName = fileParts.join('/');

    const file = storage.bucket(bucket).file(fileName);
    const stream = file.createReadStream();

    res.setHeader('Content-Type', 'audio/wav');
    stream.pipe(res);
  } catch (error) {
    console.error('Error downloading file:', error);
    res.status(500).json({ error: error.message });
  }
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

### Opción 2: Python con Flask

```python
from flask import Flask, request, jsonify, Response
from google.cloud import texttospeech
from google.cloud import storage
import time

app = Flask(__name__)

# Configurar clientes
tts_client = texttospeech.TextToSpeechLongAudioSynthesizeClient()
storage_client = storage.Client()
bucket_name = 'tu-bucket-audio'  # Reemplaza con tu bucket

@app.route('/tts/long/start', methods=['POST'])
def start_synthesis():
    try:
        data = request.json
        text = data['text']
        language_code = data.get('languageCode', 'es-ES')
        voice_name = data.get('voiceName')
        speaking_rate = data.get('speakingRate', 1.0)
        pitch = data.get('pitch', 0.0)
        output_gcs_uri = data['outputGcsUri']

        # Configurar la síntesis
        input_text = texttospeech.SynthesisInput(text=text)

        voice = texttospeech.VoiceSelectionParams(
            language_code=language_code,
            name=voice_name
        )

        audio_config = texttospeech.AudioConfig(
            audio_encoding=texttospeech.AudioEncoding.LINEAR16,
            speaking_rate=speaking_rate,
            pitch=pitch
        )

        # Iniciar operación larga
        operation = tts_client.synthesize_long_audio(
            request={
                "input": input_text,
                "voice": voice,
                "audio_config": audio_config,
                "output_gcs_uri": output_gcs_uri,
            }
        )

        return jsonify({"operationId": operation.operation.name})

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/tts/long/status', methods=['GET'])
def get_status():
    try:
        operation_id = request.args.get('operationId')

        operation = tts_client.get_operation(operation_id)

        result = {
            "done": operation.done,
            "error": None,
            "outputGcsUri": None
        }

        if operation.done:
            if operation.error:
                result["error"] = operation.error.message
            else:
                # La operación fue exitosa
                result["outputGcsUri"] = operation.metadata.output_gcs_uri

        return jsonify(result)

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/tts/long/download', methods=['GET'])
def download_audio():
    try:
        gcs_path = request.args.get('path')

        # Parsear gs://bucket/file
        if not gcs_path.startswith('gs://'):
            return jsonify({"error": "Invalid GCS path"}), 400

        path_parts = gcs_path[5:].split('/', 1)
        bucket_name = path_parts[0]
        blob_name = path_parts[1]

        bucket = storage_client.bucket(bucket_name)
        blob = bucket.blob(blob_name)

        # Descargar y retornar el archivo
        data = blob.download_as_bytes()

        return Response(data, mimetype='audio/wav')

    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
```

## 🔧 Configuración en Google Cloud

### 1. Crear Cuenta de Servicio
```bash
# Crear cuenta de servicio
gcloud iam service-accounts create naturlly-tts-service \
  --description="Service account for Naturlly TTS long audio service" \
  --display-name="Naturlly TTS Service"

# Otorgar permisos
gcloud projects add-iam-policy-binding TU_PROJECT_ID \
  --member="serviceAccount:naturlly-tts-service@TU_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/cloudtranslate.user"

gcloud projects add-iam-policy-binding TU_PROJECT_ID \
  --member="serviceAccount:naturlly-tts-service@TU_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin"

# Descargar clave JSON
gcloud iam service-accounts keys create key.json \
  --iam-account=naturlly-tts-service@TU_PROJECT_ID.iam.gserviceaccount.com
```

### 2. Crear Bucket de Storage
```bash
# Crear bucket
gsutil mb -p TU_PROJECT_ID -c STANDARD -l US gs://tu-bucket-audio

# Otorgar permisos públicos para lectura (opcional, para signed URLs)
gsutil iam ch serviceAccount:naturlly-tts-service@TU_PROJECT_ID.iam.gserviceaccount.com:objectViewer gs://tu-bucket-audio
```

### 3. Desplegar en VM

#### Para Node.js:
```bash
# Instalar dependencias
npm init -y
npm install express @google-cloud/text-to-speech @google-cloud/storage

# Configurar variable de entorno
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json

# Ejecutar
node server.js
```

#### Para Python:
```bash
# Instalar dependencias
pip install flask google-cloud-texttospeech google-cloud-storage

# Configurar variable de entorno
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json

# Ejecutar
python app.py
```

## ⚙️ Configuración en la App Naturlly

1. Abre la app y ve a **Configuración** (ícono de engranaje)
2. Activa **"Usar Servicio de Audio Largo"**
3. Configura:
   - **URL del Backend**: `https://tu-vm-ip-o-dominio`
   - **Bucket de GCS**: `tu-bucket-audio`

## 🧪 Probar la Integración

```bash
# Probar endpoint de inicio
curl -X POST https://tu-vm-url/tts/long/start \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Hola, esto es una prueba de audio largo",
    "languageCode": "es-ES",
    "outputGcsUri": "gs://tu-bucket-audio/test.wav"
  }'

# Probar endpoint de estado (reemplaza OPERATION_ID)
curl "https://tu-vm-url/tts/long/status?operationId=OPERATION_ID"

# Probar descarga
curl "https://tu-vm-url/tts/long/download?path=gs://tu-bucket-audio/test.wav" \
  --output test.wav
```

## 🚀 Despliegue en Producción

Considera usar:
- **Cloud Run** para despliegue serverless
- **App Engine** para aplicaciones más complejas
- **Kubernetes Engine** para alta escalabilidad
- **Load Balancer** para distribución de carga

¡Ahora puedes aprovechar toda la potencia de tu VM en Google Cloud para generar audio de alta calidad en Naturlly! 🎉