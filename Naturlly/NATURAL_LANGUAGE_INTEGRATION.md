# Integración de Google Cloud Natural Language API

## 🎯 Objetivo
Mejorar la calidad del audio generado mediante análisis inteligente del texto para ajustar automáticamente el tono y la velocidad según el contenido emocional.

## 📋 Archivos Creados/Modificados

### 1. **NaturalLanguageService.swift** (NUEVO)
- **Ubicación**: `/Users/mike/Documents/Naturlly/Naturlly/NaturalLanguageService.swift`
- **Tamaño**: ~250 líneas
- **Características**:
  - Análisis completo de sentimiento del texto
  - Extracción de entidades (PERSON, LOCATION, ORGANIZATION, etc.)
  - Análisis a nivel de oraciones individuales
  - Ajuste automático de parámetros de voz basado en sentimiento

#### Estructuras Principales:
```swift
struct TextAnalysis {
    let sentiment: SentimentScore       // Sentimiento general del texto
    let entities: [Entity]              // Entidades detectadas
    let sentences: [Sentence]           // Análisis por oración
    let language: String                // Idioma detectado
}
```

#### Métodos Clave:
- `analyzeText(_ text: String) -> TextAnalysis`
  - Realiza análisis completo del texto
  - Endpoint: `language.googleapis.com/v1/documents:annotateText`
  - Features: extractSyntax, extractEntities, extractDocumentSentiment

- `getSpeechParameters(from analysis:) -> (rate: Double, pitch: Double)`
  - **Sentimiento positivo (>0.5)**: pitch +2.0 (tono más alto)
  - **Sentimiento negativo (<-0.5)**: pitch -2.0 (tono más bajo)
  - **Alta magnitud (>0.7)**: rate 1.1 (más rápido para contenido emocional)
  - **Baja magnitud (<0.3)**: rate 0.95 (más lento para contenido técnico/neutral)

- `getSSMLEnhancements(from analysis:) -> String`
  - Genera sugerencias de énfasis
  - Identifica entidades importantes (salience > 0.1)
  - Proporciona recomendaciones de tono

### 2. **ContentView.swift** (MODIFICADO)
Cambios realizados:

#### Variables Agregadas:
```swift
@State private var useNaturalAnalysis: Bool = false
@State private var analysisResult: String?
```

#### Función `generateSpeech()` - ACTUALIZADA
- Ahora verifica si `useNaturalAnalysis` está activado
- Si está activado:
  1. Crea instancia de `NaturalLanguageService`
  2. Analiza el texto con `analyzeText()`
  3. Obtiene parámetros sugeridos con `getSpeechParameters()`
  4. Muestra resultados del análisis en la UI
  5. Aplica parámetros ajustados al TTS
- Si está desactivado: funciona como antes (usa valores manuales)

#### UI - Toggle de Análisis Inteligente
Nuevo componente agregado antes de "Ajustes de voz":
```swift
Toggle(isOn: $useNaturalAnalysis) {
    HStack {
        Image(systemName: "brain.head.profile")
        VStack {
            Text("Análisis Inteligente")
            Text("Ajusta automáticamente tono y velocidad según el contenido")
        }
    }
}
.onChange(of: useNaturalAnalysis) { _ in saveAnalysisPreference() }
```

Display de resultados del análisis:
```swift
if let result = analysisResult {
    Text(result)
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(8)
        .background(Color.tertiarySystemBackground)
        .cornerRadius(6)
}
```

#### Persistencia
- `loadAPIKey()` - ACTUALIZADA: Ahora también carga `useNaturalAnalysis` de UserDefaults
- `saveAnalysisPreference()` - NUEVA: Guarda estado del toggle en UserDefaults

## 🚀 Características Implementadas

### Análisis de Sentimiento
- **Score**: Rango de -1.0 (muy negativo) a 1.0 (muy positivo)
- **Magnitude**: 0.0 a infinito, indica intensidad emocional
- Ejemplo:
  - "¡Excelente día!" → score: 0.8, magnitude: 0.9
  - "Esto es terrible" → score: -0.7, magnitude: 0.8
  - "El auto es rojo" → score: 0.1, magnitude: 0.2

### Extracción de Entidades
- Tipos soportados: PERSON, LOCATION, ORGANIZATION, EVENT, WORK_OF_ART, etc.
- Salience: 0.0 a 1.0 (importancia relativa en el texto)
- Mentions: Todas las menciones de cada entidad

### Ajuste Automático de Parámetros
| Característica del Texto | Ajuste de Rate | Ajuste de Pitch |
|--------------------------|----------------|-----------------|
| Muy positivo (>0.5) | 1.0 (normal) | +2.0 (alegre) |
| Muy negativo (<-0.5) | 1.0 (normal) | -2.0 (serio) |
| Alta emoción (mag>0.7) | 1.1 (rápido) | Según sentimiento |
| Neutral/técnico (mag<0.3) | 0.95 (lento) | 0.0 (neutro) |

## 📊 Display de Análisis en UI
Cuando el análisis está activo, se muestra:
```
📊 Análisis de Texto:
• Sentimiento: 0.75 (magnitud: 0.82)
• Entidades detectadas: 5
• Velocidad ajustada: 1.10x
• Tono ajustado: 2.0

Tono positivo detectado - considerar voz más animada
Entidades importantes detectadas: María, París, Universidad
```

## 🔧 Uso

### Para el Usuario:
1. Activar el toggle "Análisis Inteligente"
2. Escribir o cargar texto
3. Presionar "Generar Audio"
4. El sistema automáticamente:
   - Analiza el sentimiento y contenido
   - Ajusta velocidad y tono
   - Muestra el análisis
   - Genera audio optimizado

### Beneficios:
- ✅ **Audio más natural**: Tono y velocidad se adaptan al contenido
- ✅ **Contenido emocional**: Voces más expresivas para textos positivos/negativos
- ✅ **Contenido técnico**: Velocidad reducida para mejor comprensión
- ✅ **Transparencia**: Usuario ve el análisis y ajustes realizados
- ✅ **Persistencia**: Preferencia se guarda automáticamente

## 🔑 Requisitos
- Misma API Key de Google Cloud
- Natural Language API debe estar habilitada en el proyecto de Google Cloud
- No requiere autenticación adicional (usa la misma API Key que TTS)

## ⚙️ Configuración en Google Cloud
1. Ir a Google Cloud Console
2. Habilitar "Cloud Natural Language API"
3. Usar la misma API Key existente
4. No hay costo adicional para análisis básico (ver límites gratuitos)

## 🎨 Estado de la Implementación
✅ NaturalLanguageService.swift creado
✅ Análisis de sentimiento completo
✅ Extracción de entidades
✅ Análisis por oraciones
✅ Ajuste automático de parámetros
✅ Integración en ContentView
✅ Toggle UI agregado
✅ Display de resultados
✅ Persistencia de preferencias
✅ Sin errores de compilación

## 📝 Notas Técnicas
- El análisis se ejecuta antes del TTS si está habilitado
- Los parámetros manuales se sobrescriben cuando el análisis está activo
- El usuario puede desactivar el análisis en cualquier momento
- La preferencia se guarda en UserDefaults con clave "UseNaturalAnalysis"
- El servicio usa async/await para no bloquear la UI
