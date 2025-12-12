# 🎯 Cómo Usar el Análisis Inteligente de Texto

## 📱 Pasos para Activar

### 1. Configurar Google Cloud Natural Language API

Antes de usar la función de análisis inteligente, debes habilitar la API en tu proyecto de Google Cloud:

1. Ve a [Google Cloud Console](https://console.cloud.google.com/)
2. Selecciona tu proyecto (el mismo que usas para Text-to-Speech)
3. Ve a "APIs & Services" > "Library"
4. Busca "Cloud Natural Language API"
5. Haz clic en "Enable" (Habilitar)
6. **No necesitas crear una nueva API Key** - usa la misma que ya tienes para TTS

### 2. Usar en la App

1. **Abre la app Naturlly**
2. **Configura tu API Key** (si aún no lo has hecho):
   - Toca el ícono de configuración (⚙️)
   - Ingresa tu API Key de Google Cloud
   - Guarda

3. **Activa el Análisis Inteligente**:
   - Verás un toggle con el ícono de cerebro 🧠
   - Texto: "Análisis Inteligente"
   - Subtexto: "Ajusta automáticamente tono y velocidad según el contenido"
   - **Actívalo** deslizando el switch

4. **Escribe o carga tu texto**:
   - Puedes escribir directamente en el editor
   - O cargar un documento PDF/EPUB

5. **Genera el audio**:
   - Presiona "Generar Audio"
   - La app automáticamente:
     * ✨ Analiza el sentimiento de tu texto
     * 🔍 Detecta entidades importantes
     * ⚡ Ajusta velocidad y tono
     * 🎵 Genera audio optimizado

6. **Revisa el análisis**:
   - Debajo del toggle verás un panel con:
     * Sentimiento detectado (-1.0 a 1.0)
     * Magnitud emocional
     * Número de entidades detectadas
     * Velocidad y tono aplicados
     * Sugerencias de mejora

## 🎨 Ejemplos de Uso

### Ejemplo 1: Texto Positivo y Emocionante
**Texto**: "¡Qué día tan maravilloso! Estoy muy feliz de estar aquí. Todo es perfecto."

**Resultado del análisis**:
```
📊 Análisis de Texto:
• Sentimiento: 0.85 (magnitud: 0.92)
• Entidades detectadas: 0
• Velocidad ajustada: 1.10x
• Tono ajustado: 2.0

Tono positivo detectado - considerar voz más animada
```

**Audio generado**: Voz alegre, tono alto, velocidad rápida ✨

---

### Ejemplo 2: Texto Negativo o Serio
**Texto**: "Lamentablemente, las condiciones no son favorables. Debemos tomar medidas urgentes."

**Resultado del análisis**:
```
📊 Análisis de Texto:
• Sentimiento: -0.65 (magnitud: 0.78)
• Entidades detectadas: 0
• Velocidad ajustada: 1.10x
• Tono ajustado: -2.0

Tono negativo detectado - considerar voz más seria
```

**Audio generado**: Voz seria, tono bajo, transmite urgencia 📉

---

### Ejemplo 3: Texto Técnico o Neutral
**Texto**: "El proceso de fotosíntesis ocurre en los cloroplastos. La clorofila absorbe la luz solar."

**Resultado del análisis**:
```
📊 Análisis de Texto:
• Sentimiento: 0.05 (magnitud: 0.15)
• Entidades detectadas: 2
• Velocidad ajustada: 0.95x
• Tono ajustado: 0.0

Entidades importantes detectadas: fotosíntesis, cloroplastos
```

**Audio generado**: Voz calmada, velocidad reducida para comprensión 📚

---

### Ejemplo 4: Historia con Personajes
**Texto**: "María viajó a París el año pasado. Visitó la Torre Eiffel y el Museo del Louvre."

**Resultado del análisis**:
```
📊 Análisis de Texto:
• Sentimiento: 0.25 (magnitud: 0.45)
• Entidades detectadas: 4
• Velocidad ajustada: 1.00x
• Tono ajustado: 0.0

Entidades importantes detectadas: María, París, Torre Eiffel, Museo del Louvre
```

**Audio generado**: Énfasis en nombres propios, ritmo narrativo 🗼

## ⚙️ Opciones de Configuración

### Desactivar el Análisis
- Simplemente desactiva el toggle "Análisis Inteligente"
- Los ajustes manuales de velocidad y tono volverán a funcionar
- Tu preferencia se guarda automáticamente

### Combinar con Ajustes Manuales
- **Con análisis DESACTIVADO**: Usa los sliders de velocidad y tono manualmente
- **Con análisis ACTIVADO**: Los valores se ajustan automáticamente
  - Los sliders manuales se ignoran temporalmente
  - El análisis determina los mejores parámetros

## 💡 Consejos

1. **Para textos emocionales**: Activa el análisis para voces más expresivas
2. **Para textos técnicos**: El análisis reduce la velocidad automáticamente
3. **Para narrativas**: El análisis resalta entidades importantes (nombres, lugares)
4. **Para pruebas**: Desactiva el análisis si prefieres control manual total

## 🚀 Beneficios

✅ **Automatización**: No necesitas ajustar manualmente cada texto
✅ **Naturalidad**: El audio suena más humano y expresivo
✅ **Inteligencia**: El sistema entiende el contexto emocional
✅ **Transparencia**: Ves exactamente qué ajustes se aplicaron
✅ **Flexibilidad**: Activa o desactiva según tus necesidades

## 📊 Costo

- La API de Natural Language tiene un **nivel gratuito**:
  - 5,000 unidades/mes gratis
  - Cada análisis de texto consume 1 unidad por cada 1,000 caracteres
  - Ejemplo: Un texto de 3,000 caracteres = 3 unidades
  
- Para la mayoría de usuarios, **el uso personal es GRATIS** ✨

## ❓ Preguntas Frecuentes

**P: ¿Necesito una API Key diferente?**
R: No, usa la misma API Key de Google Cloud Text-to-Speech.

**P: ¿Funciona con todos los idiomas?**
R: Sí, la Natural Language API soporta múltiples idiomas incluyendo español.

**P: ¿Puedo ver el análisis sin generar audio?**
R: Actualmente el análisis se ejecuta al generar audio. Próxima versión tendrá preview.

**P: ¿Los ajustes manuales se pierden?**
R: No, al desactivar el análisis, tus ajustes manuales se restauran.

**P: ¿Qué pasa si la API falla?**
R: La app mostrará un error y generará el audio con tus ajustes manuales.

## 🆘 Solución de Problemas

### Error: "Falta la API Key"
- Verifica que configuraste tu API Key en ajustes
- La API Key debe ser válida

### Error: "API no habilitada"
- Ve a Google Cloud Console
- Habilita "Cloud Natural Language API"
- Espera 2-3 minutos

### Error: "Quota exceeded"
- Has superado el límite gratuito de 5,000 unidades/mes
- Espera al siguiente mes o actualiza tu plan

### El análisis no aparece
- Verifica que el toggle esté activado
- Asegúrate de tener texto escrito
- Revisa tu conexión a internet

---

**¿Necesitas más ayuda?**
Contacta al soporte o consulta la [documentación de Google Cloud Natural Language](https://cloud.google.com/natural-language/docs)
