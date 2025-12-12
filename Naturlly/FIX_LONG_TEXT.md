# 🔧 Solución: Error 400 - Texto Demasiado Largo

## Problema Original

```
Error 400: "input.text" is longer than the limit of 5000 bytes
```

Google TTS tiene un límite de **5000 bytes por request**.

---

## ✅ Solución Implementada

### Funcionalidades Agregadas:

1. **Detección automática** del tamaño del texto
2. **División inteligente** en fragmentos <4500 bytes
3. **Procesamiento por lotes** con delays entre requests
4. **Unión automática** de archivos de audio MP3
5. **Transparente para el usuario** - sin cambios en UI

---

## 🎯 Cómo Funciona

### Texto Corto (≤5000 bytes)
```
Texto → API Request → Audio MP3 → Reproducir
```

### Texto Largo (>5000 bytes)
```
Texto → División en Fragmentos
      ↓
      Fragmento 1 → API → Audio 1
      Fragmento 2 → API → Audio 2 (delay 0.5s)
      Fragmento 3 → API → Audio 3 (delay 0.5s)
      ↓
      Unión de Audios → Audio Completo → Reproducir
```

---

## 📐 División Inteligente

El texto se divide respetando:

1. **Por oraciones**: Busca puntos (`.`), signos de exclamación (`!`), interrogación (`?`)
2. **Por palabras**: Si una oración es muy larga, se divide por espacios
3. **Mantiene puntuación**: No pierde el contexto ni la entonación

### Ejemplo:

Texto de 15,000 bytes:
```
"Hola mundo. Este es un texto largo..."
        ↓
Fragmento 1: "Hola mundo. Este es un texto largo..." (4500 bytes)
Fragmento 2: "...continuación del texto..." (4500 bytes)
Fragmento 3: "...final del texto." (4000 bytes)
```

---

## ⏱️ Tiempos de Procesamiento

| Tamaño del Texto | Fragmentos | Tiempo Aprox. |
|------------------|------------|---------------|
| <5,000 bytes     | 1          | 1-2 segundos  |
| 10,000 bytes     | 2-3        | 3-4 segundos  |
| 20,000 bytes     | 4-5        | 5-7 segundos  |
| 50,000 bytes     | 10-12      | 12-15 segundos|

**Nota**: Incluye 0.5s de delay entre cada fragmento para evitar rate limiting.

---

## 🔍 Logs de Consola

Durante el procesamiento verás:
```
Procesando fragmento 1 de 5...
Procesando fragmento 2 de 5...
Procesando fragmento 3 de 5...
Procesando fragmento 4 de 5...
Procesando fragmento 5 de 5...
```

---

## �� Unión de Audio

Los archivos MP3 se concatenan de forma simple pero efectiva:
```swift
var mergedData = Data()
for chunk in audioChunks {
    mergedData.append(chunk)
}
```

MP3 soporta concatenación directa sin necesidad de re-encoding.

---

## ⚙️ Configuración

### Límite configurable:
```swift
private let maxBytesPerRequest = 4500
```

Se usa 4500 en lugar de 5000 para:
- Margen de seguridad
- Headers JSON adicionales
- Caracteres especiales que ocupan más bytes

### Delay entre requests:
```swift
try await Task.sleep(nanoseconds: 500_000_000) // 0.5 segundos
```

Evita que Google marque las requests como spam.

---

## 📊 Casos de Uso

### PDF Pequeño (1-2 páginas):
- ~2,000-5,000 bytes
- 1 request
- 1-2 segundos

### PDF Mediano (5-10 páginas):
- ~10,000-25,000 bytes
- 3-6 requests
- 4-8 segundos

### Libro EPUB (Capítulo completo):
- ~50,000-100,000 bytes
- 12-25 requests
- 15-30 segundos

---

## ⚠️ Limitaciones

### Rate Limiting de Google:
- Google puede limitar requests muy rápidos
- Solución: Delay de 0.5s entre fragmentos

### Cuota Mensual:
- 4M caracteres gratis/mes
- Textos largos consumen más cuota
- Monitorea tu uso en Google Cloud Console

### Calidad de Audio:
- La unión es perfecta para MP3
- Puede haber pequeñas pausas imperceptibles entre fragmentos

---

## 🐛 Debugging

Si encuentras problemas:

### Audio cortado:
```swift
// Aumenta el delay
try await Task.sleep(nanoseconds: 1_000_000_000) // 1 segundo
```

### Errores de cuota:
```swift
// Reduce el texto o espera
```

### Fragmentos mal divididos:
```swift
// Ajusta maxBytesPerRequest
private let maxBytesPerRequest = 4000
```

---

## ✨ Mejoras Futuras

### Indicador de Progreso en UI:
```swift
@Published var processingProgress: Double = 0.0
// Actualizar en cada fragmento
```

### Caché de Fragmentos:
```swift
// Guardar fragmentos procesados
// Evitar re-procesar si se repite el texto
```

### Procesamiento Paralelo:
```swift
// Procesar múltiples fragmentos simultáneamente
// (cuidado con rate limiting)
```

---

## 🎉 ¡Listo!

Ahora puedes convertir documentos de cualquier tamaño a audio.

**Antes**: Límite de 5000 bytes (~1 página)
**Ahora**: Sin límite práctico (solo cuota mensual)

¡Disfruta convirtiendo tus documentos largos a audio!
