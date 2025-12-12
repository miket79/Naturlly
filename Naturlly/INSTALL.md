# Naturlly TTS - Instrucciones de Instalación

## 🚀 Cómo crear el proyecto en Xcode

### Paso 1: Crear el Proyecto en Xcode

1. **Abre Xcode**
2. **File → New → Project** (o presiona `⌘⇧N`)
3. Selecciona **iOS → App**
4. Click **Next**
5. Configura el proyecto:
   - **Product Name:** `Naturlly`
   - **Team:** (Selecciona tu equipo de desarrollo)
   - **Organization Identifier:** `com.yourname` (o tu identificador)
   - **Bundle Identifier:** Se generará automáticamente como `com.yourname.Naturlly`
   - **Interface:** `SwiftUI`
   - **Language:** `Swift`
   - **Storage:** Ninguno
   - **Include Tests:** (opcional, puedes desmarcarlo)
6. Click **Next**
7. Selecciona `/Users/mike/Downloads` como ubicación
8. **IMPORTANTE**: Desmarca "Create Git repository" si ya existe
9. Click **Create**

### Paso 2: Reemplazar archivos por defecto

Xcode habrá creado algunos archivos por defecto. Ahora vamos a reemplazarlos:

1. **Eliminar el archivo por defecto:**
   - En el navegador de archivos (izquierda), encuentra y **elimina** el archivo `NaturllyApp.swift` o `ContentView.swift` que Xcode creó
   - Selecciona "Move to Trash"

2. **Agregar nuestros archivos:**
   - Arrastra estos archivos desde `/Users/mike/Downloads/NaturllyTTS/` al proyecto en Xcode:
     - `NaturllyApp.swift`
     - `ContentView.swift`
     - `TTSLanguage.swift`
     - `TTSRequest.swift`
     - `GoogleTTSService.swift`
     - `AudioPlayerManager.swift`
   - Cuando aparezca el diálogo:
     - ✅ Marca "Copy items if needed"
     - ✅ Marca "Create groups"
     - ✅ Asegúrate de que el target "Naturlly" esté seleccionado
   - Click **Finish**

### Paso 3: Organizar archivos (Opcional pero recomendado)

Para mejor organización, crea grupos en Xcode:

1. **Right-click** en la carpeta "Naturlly" → **New Group**
2. Nombra el grupo "Models"
3. Arrastra `TTSLanguage.swift` y `TTSRequest.swift` a este grupo
4. Repite para crear:
   - Grupo "Services" → mueve `GoogleTTSService.swift` y `AudioPlayerManager.swift`
   - Grupo "Views" → mueve `ContentView.swift`

### Paso 4: Configurar Info.plist

1. En el navegador de archivos, selecciona el proyecto "Naturlly" (arriba del todo)
2. Selecciona el target "Naturlly"
3. Ve a la pestaña **Info**
4. En "Custom iOS Target Properties", haz click en el `+` para agregar:
   - Key: `NSAppTransportSecurity` (Type: Dictionary)
     - Dentro de este, agrega:
       - Key: `NSExceptionDomains` (Type: Dictionary)
         - Dentro de este, agrega:
           - Key: `texttospeech.googleapis.com` (Type: Dictionary)
             - Dentro de este, agrega:
               - Key: `NSExceptionAllowsInsecureHTTPLoads` → Value: `NO` (Boolean)
               - Key: `NSIncludesSubdomains` → Value: `YES` (Boolean)
               - Key: `NSExceptionMinimumTLSVersion` → Value: `TLSv1.2` (String)

O más fácil: copia el contenido del archivo `Info.plist` que está en `/Users/mike/Downloads/NaturllyTTS/`

### Paso 5: Build y Run

1. Selecciona un simulador (ej: "iPhone 15 Pro")
2. Click en el botón **Play** (▶️) o presiona `⌘R`
3. ¡La app debería compilar y ejecutarse!

## 🔧 Solución al Error "Executable Path is a Directory"

Este error ocurre cuando el proyecto no está correctamente configurado. Si lo sigues encontrando:

1. **Clean Build Folder:**
   - `Product → Clean Build Folder` (o `⌘⇧K`)

2. **Derived Data:**
   - `Xcode → Settings → Locations`
   - Click en la flecha junto a "Derived Data"
   - Elimina la carpeta del proyecto (que empieza con "Naturlly-...")
   - Cierra y reabre Xcode

3. **Verifica el Target:**
   - Selecciona el proyecto → Target "Naturlly"
   - En "General" → asegúrate de que "Bundle Identifier" sea válido
   - En "Build Settings" → busca "Product Name" y verifica que sea "Naturlly"

4. **Reconstruye:**
   - `Product → Build` (`⌘B`)
   - Si compila sin errores, intenta `Product → Run` (`⌘R`)

## 📝 Obtener API Key de Google

1. Ve a [Google Cloud Console](https://console.cloud.google.com)
2. Crea un proyecto o selecciona uno existente
3. Habilita **Cloud Text-to-Speech API**:
   - APIs & Services → Library
   - Busca "Cloud Text-to-Speech API"
   - Click "Enable"
4. Crea credenciales:
   - APIs & Services → Credentials
   - Create Credentials → API Key
   - Copia la clave generada
5. En la app iOS, toca el ícono de configuración e ingresa tu API Key

## ✅ Verificación

Después de completar los pasos, deberías ver:

```
Naturlly/
├── NaturllyApp.swift
├── Views/
│   └── ContentView.swift
├── Models/
│   ├── TTSLanguage.swift
│   └── TTSRequest.swift
└── Services/
    ├── GoogleTTSService.swift
    └── AudioPlayerManager.swift
```

Y la app debería compilar sin errores.

## 🆘 Ayuda

Si tienes problemas:

1. Verifica que todos los archivos Swift estén en el target
2. Asegúrate de que no haya errores de sintaxis
3. Limpia el build folder y derived data
4. Reinicia Xcode

¡Listo! Tu app iOS de Text-to-Speech debería funcionar perfectamente. 🎉
