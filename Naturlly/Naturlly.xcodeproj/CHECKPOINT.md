// Naturlly TTS — Checkpoint Pre-Cambios (2025-12-20)

// Este archivo documenta un punto de retorno seguro antes de aplicar cambios de pulido y lanzamiento. Úsalo para crear un commit/tag/branch desde el que puedas volver rápidamente si algo no resulta.

// Objetivo
// Crear un checkpoint (commit + tag) y, opcionalmente, una rama de trabajo para los cambios de acabado y preparación de TestFlight/App Store.

// Estado actual (inventario rápido)
// Archivos clave presentes:
// - NaturllyApp.swift (punto de entrada @main)
// - ContentView.swift (UI principal y lógica TTS/Modo Libro)
// - VoicePickerView.swift (selector de voces)
// - TTSVoice.swift (modelo de voces)
// - TTSLanguage.swift (idiomas)
// - GoogleTTSService.swift (cliente Cloud Text-to-Speech)
// - NaturalLanguageService.swift (análisis de texto)
// - AudioPlayerManager.swift (reproducción y progreso)
// - Document.swift (modelo de documentos y secciones)
// - PDFDocumentReader.swift (importación PDF)
// - EPUBReader.swift (importación EPUB)
// - DocumentPicker.swift (UIDocumentPicker)
// - INSTALL.md, INSTRUCCIONES_USUARIO.md (documentación)
// - AppDelegate.swift (presente; revisar coexistencia con @main)

// Archivos referenciados y no encontrados (crear/ajustar en próximos pasos):
// - LibraryView.swift
// - DocumentSectionsView.swift
// - DocumentPresentationView.swift
// - VoiceService.swift
// - APIConfig.swift (con `defaultGoogleTTSAPIKey`)

// Notas técnicas destacadas:
// - Límite de división de texto inconsistente (4000 vs 900 bytes). Unificar a ~4500 bytes para TTS clásico.
// - `useSSMLPauses` existe pero no se aplica en la petición (SSML) todavía.
// - EPUB en iOS usa fallback simple; considerar marcar como “experimental” o mejorar extracción.

// Cómo crear el checkpoint (Git — Terminal)
// 1) Asegúrate de tener Git inicializado en el proyecto.
// 2) Ejecuta:
// ```
// git add -A
// git commit -m "Checkpoint: pre-lanzamiento 1.0 (2025-12-20)"
// git tag -a pre-lanzamiento-2025-12-20 -m "Checkpoint pre cambios"
// # (Opcional) Crea una rama de trabajo para los cambios:
// git switch -c feature/market-polish
// ```

// Para volver a este punto más adelante:
// ```
// # Restablecer el árbol de trabajo a la etiqueta del checkpoint
// git reset --hard pre-lanzamiento-2025-12-20

// # O crear una rama nueva desde el checkpoint (sin perder tu trabajo actual):
// git switch -c restore/pre-lanzamiento pre-lanzamiento-2025-12-20
// ```

// Cómo crear el checkpoint (Xcode — GUI)
// 1) Source Control → Commit…
//    - Mensaje: "Checkpoint: pre-lanzamiento 1.0 (2025-12-20)"
//    - Commit
// 2) Source Control → Tag…
//    - Tag: `pre-lanzamiento-2025-12-20`
//    - Create
// 3) (Opcional) Source Control → New Branch…
//    - Branch: `feature/market-polish`

// Para volver al checkpoint en Xcode: Source Control → Checkout… → selecciona la etiqueta `pre-lanzamiento-2025-12-20` o la rama `restore/pre-lanzamiento` si la creaste.

// Cambios planeados después del checkpoint (resumen)
// - Retirar o adaptar `AppDelegate.swift` para evitar conflicto con `@main`.
// - Crear `APIConfig.swift`, `VoiceService.swift`, y las vistas faltantes (`LibraryView`, `DocumentSectionsView`, `DocumentPresentationView`).
// - Unificar el algoritmo y límite de división de texto (~4500 bytes) entre `ContentView` y `GoogleTTSService`.
// - (Opcional) Implementar SSML cuando `useSSMLPauses == true`.
// - (Opcional) Añadir Now Playing/Remote Commands para control desde lock screen.

// Verificación rápida del checkpoint
// - Ver commits: `git log --oneline -n 5`
// - Ver etiqueta: `git show --summary pre-lanzamiento-2025-12-20`
// - Guardar el hash del commit actual (opcional): `git rev-parse HEAD`

// Si no usas Git
// - Crea un archivo ZIP de la carpeta del proyecto y nómbralo: `NaturllyTTS_checkpoint_2025-12-20.zip`.
// - Guarda el ZIP fuera del directorio del proyecto (por ejemplo, en el Escritorio).

// —
// Este archivo es solo documentación/guía. El checkpoint real se materializa al crear el commit/tag en Git o el ZIP de respaldo.
