//
//  ContentView.swift
//  Naturlly TTS
//
//  Main user interface
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @State private var text: String = ""
    @State private var selectedLanguage = TTSLanguage.availableLanguages[0]
    @State private var selectedVoice: TTSVoice? = nil
    @State private var showVoicePicker = false
    @State private var speakingRate: Double = 1.0
    @State private var pitch: Double = 0.0
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSettings = false
    @State private var apiKey: String = (UserDefaults.standard.string(forKey: "GoogleTTSAPIKey") ?? APIConfig.defaultGoogleTTSAPIKey)
    @State private var audioData: Data?
    @State private var documents: [Document] = []
    @State private var showDocumentPicker = false
    @State private var selectedDocument: Document?
    @State private var showDocuments = false
    @State private var selectedSection: DocumentSection?
    @State private var showSections = false
    @State private var useNaturalAnalysis: Bool = false
    @State private var analysisResult: String?
    @State private var useSSMLPauses: Bool = true
    @State private var showDocumentPresentation = false
    @State private var presentationDocument: Document?
    @State private var currentSectionIndex: Int = 0
    @State private var autoPlaySections: Bool = false
    @State private var sectionsQueue: [DocumentSection] = []
    @State private var useVertexVoices: Bool = UserDefaults.standard.bool(forKey: "UseVertexVoices")
    
    // Estados para continuidad de lectura
    @State private var lastReadDocument: Document?
    @State private var lastReadSectionIndex: Int = 0
    @State private var lastPlaybackPosition: TimeInterval = 0
    @State private var canContinueReading: Bool = false
    
    // Estados para Modo Libro (pre-generación y caché)
    @State private var bookMode: Bool = true // Activado por defecto para mejor experiencia
    @State private var audioCache: [String: Data] = [:] // Cache en memoria
    @State private var preloadedSections: Set<Int> = [] // Índices de secciones pre-cargadas
    @State private var isPreloading: Bool = false
    @State private var preloadProgress: Double = 0.0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Continuar Lectura Button
                    if canContinueReading, let document = lastReadDocument {
                        Button(action: {
                            continueReading()
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "play.circle.fill")
                                            .font(.title2)
                                        Text("Continuar Lectura")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                    }
                                    
                                    Text(document.name)
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.9))
                                        .lineLimit(1)
                                    
                                    if sectionsQueue.count > 0 && lastReadSectionIndex < sectionsQueue.count {
                                        Text("Sección \(lastReadSectionIndex + 1) de \(sectionsQueue.count)")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(
                                    colors: [Color.green, Color.green.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: Color.green.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    
                    // API Key Section
                    if apiKey.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.orange)
                            
                            Text("Configura tu API Key")
                                .font(.headline)
                            
                            Text("Necesitas una clave API de Google Cloud Text-to-Speech")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button(action: { showSettings = true }) {
                                Label("Configurar", systemImage: "gearshape.fill")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                        }
                        .padding()
                    } else {
                        // Document Import Section
                        HStack(spacing: 12) {
                            Button(action: { showDocumentPicker = true }) {
                                Label("Importar PDF/EPUB", systemImage: "doc.badge.plus")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.green)
                                    .cornerRadius(8)
                            }
                            
                            if !documents.isEmpty {
                                Button(action: { showDocuments = true }) {
                                    Label("Mis Documentos (\(documents.count))", systemImage: "folder.fill")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(Color.blue)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        
                        // Show selected document info
                        if let doc = selectedDocument {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: doc.type.icon)
                                        .foregroundColor(.blue)
                                    Text(doc.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Button(action: {
                                        selectedDocument = nil
                                        text = ""
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                Text("\(doc.characterCount) caracteres • \(doc.wordCount) palabras")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                        
                        // Text Input Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text(selectedDocument != nil ? "Texto del documento" : "Texto a convertir")
                                .font(.headline)
                            
                            TextEditor(text: $text)
                                .frame(height: 120)
                                .padding(8)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        // Language Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Idioma")
                                .font(.headline)
                            
                            Picker("Idioma", selection: $selectedLanguage) {
                                ForEach(TTSLanguage.availableLanguages) { language in
                                    Text(language.name).tag(language)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(8)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                        
                        }
                        
                        // Voice Selection
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Voz")
                                    .font(.headline)
                                Spacer()
                                if selectedVoice != nil {
                                    Button("Por defecto") {
                                        selectedVoice = nil
                                    }
                                    .font(.caption)
                                }
                            }
                            
                            Button(action: { showVoicePicker = true }) {
                                HStack {
                                    Image(systemName: "waveform.circle.fill")
                                        .foregroundColor(.blue)
                                    
                                    if let voice = selectedVoice {
                                        VStack(alignment: .leading, spacing:2) {
                                            Text(voice.name)
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                            Text("\(voice.gender == .male ? "Masculina" : "Femenina") - \(voice.type.displayName)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    } else {
                                        Text("Voz automática")
                                            .foregroundColor(.primary)
                                        Text("(Toca para elegir)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .padding(12)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(8)
                            }
                        
                        // Natural Language Analysis Toggle
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: $useNaturalAnalysis) {
                                HStack {
                                    Image(systemName: "brain.head.profile")
                                        .foregroundColor(.purple)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Análisis Inteligente")
                                            .font(.headline)
                                        Text("Ajusta automáticamente tono y velocidad según el contenido")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .tint(.purple)
                            
                            if let result = analysisResult {
                                Text(result)
                                .onChange(of: useNaturalAnalysis) { saveAnalysisPreference() }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(8)
                                    .background(Color(UIColor.tertiarySystemBackground))
                                    .cornerRadius(6)
                            }
                        }
                        .padding(12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                        
                        // SSML Pauses Toggle
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: $useSSMLPauses) {
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(.orange)
                                    VStack(alignment: .leading, spacing:2) {
                                        Text("Pausas Naturales")
                                            .font(.headline)
                                        Text("Agrega pausas automáticas en comas y puntos")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .tint(.orange)
                            .onChange(of: useSSMLPauses) { saveSSMLPreference() }
                        }
                        .padding(12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)


                        // Voice Settings (Compact)
                        DisclosureGroup {
                            VStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Velocidad")
                                            .font(.subheadline)
                                        Spacer()
                                        Text(String(format: "%.1fx", speakingRate))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    Slider(value: $speakingRate, in: 0.5...2.0, step: 0.1)
                                        .tint(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Tono")
                                            .font(.subheadline)
                                        Spacer()
                                        Text(String(format: "%.1f", pitch))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    Slider(value: $pitch, in: -20.0...20.0, step: 1.0)
                                        .tint(.blue)
                                }
                            }
                            .padding(.top, 8)
                        } label: {
                            HStack {
                                Text("Ajustes de voz")
                                    .font(.headline)
                                Spacer()
                                Text("Velocidad: \(String(format: "%.1fx", speakingRate)) | Tono: \(String(format: "%.0f", pitch))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(.blue)
                        
                        // Toggle Modo Libro
                        if selectedDocument?.hasSections == true {
                            Toggle(isOn: $bookMode) {
                                HStack {
                                    Image(systemName: bookMode ? "book.fill" : "book")
                                        .foregroundColor(bookMode ? .green : .gray)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Modo Libro")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        Text(bookMode ? "Pre-carga activada ⚡️" : "Genera bajo demanda")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding()
                            .background(bookMode ? Color.green.opacity(0.1) : Color.gray.opacity(0.05))
                            .cornerRadius(8)
                        }
                        
                        // Generate Button
                        Button(action: generateSpeech) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "waveform")
                                }
                                Text(isLoading ? "Generando..." : "Generar Audio")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(text.isEmpty || isLoading ? Color.gray : Color.blue)
                            .cornerRadius(12)
                        }
                        .disabled(text.isEmpty || isLoading)
                        
                        // Audio Player Section
                        if audioData != nil {
                            VStack(spacing: 16) {
                                Divider()
                                
                                // Playback Controls
                                VStack(spacing: 12) {
                                    // Progress Bar
                                    VStack(spacing: 4) {
                                        Slider(
                                            value: Binding(
                                                get: { audioPlayer.currentTime },
                                                set: { audioPlayer.seek(to: $0) }
                                            ),
                                            in: 0...max(audioPlayer.duration, 0.1)
                                        )
                                        .disabled(!audioPlayer.isPlaying && audioPlayer.currentTime == 0)
                                        
                                        HStack {
                                            Text(formatTime(audioPlayer.currentTime))
                                            Spacer()
                                            Text(formatTime(audioPlayer.duration))
                                        }
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    }
                                    
                                    // Play/Pause Button
                                    HStack(spacing: 32) {
                                        Button(action: {
                                            if audioPlayer.isPlaying {
                                                // Guardar progreso antes de pausar
                                                saveReadingProgress()
                                                audioPlayer.pause()
                                            } else if audioPlayer.currentTime > 0 {
                                                audioPlayer.resume()
                                            } else if let data = audioData {
                                                audioPlayer.nowPlayingTitle = buildNowPlayingTitle()
                                                try? audioPlayer.playAudio(data: data)
                                            }
                                        }) {
                                            Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                                .font(.system(size: 64))
                                                .foregroundColor(.blue)
                                        }
                                        
                                        Button(action: {
                                            // Guardar progreso antes de detener
                                            saveReadingProgress()
                                            audioPlayer.stop()
                                        }) {
                                            Image(systemName: "stop.circle.fill")
                                                .font(.system(size: 48))
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(12)
                            }
                            
                            // Indicador de Modo Libro y Pre-carga
                            if bookMode && !sectionsQueue.isEmpty {
                                VStack(spacing: 12) {
                                    HStack {
                                        Image(systemName: "book.fill")
                                            .foregroundColor(.green)
                                        Text("Modo Libro Activado")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        Spacer()
                                        if isPreloading {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        }
                                    }
                                    
                                    if !preloadedSections.isEmpty {
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.caption)
                                            Text("\(preloadedSections.count) secciones pre-cargadas")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                        }
                                    }
                                    
                                    if isPreloading {
                                        HStack {
                                            Image(systemName: "arrow.down.circle")
                                                .foregroundColor(.blue)
                                                .font(.caption)
                                            Text("Pre-cargando próximas secciones...")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                        }
                                    }
                                }
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        
                        // Error Message
                        if let error = errorMessage {
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Naturlly TTS")
            .toolbar {
                if apiKey.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(apiKey: $apiKey, useVertexVoices: $useVertexVoices)
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker(
                    documents: $documents,
                    isPresented: $showDocumentPicker,
                    errorMessage: $errorMessage
                )
            }
            .sheet(isPresented: $showDocuments) {
                DocumentListView(
                    documents: $documents,
                    selectedDocument: $selectedDocument,
                    text: $text,
                    isPresented: $showDocuments,
                    selectedSection: $selectedSection,
                    showSections: $showSections,
                    onPresentDocument: { document in
                        presentationDocument = document
                        showDocumentPresentation = true
                    }
                )
            }
            .sheet(isPresented: $showSections) {
                if let document = selectedDocument {
                    DocumentSectionsView(
                        document: document,
                        selectedSection: $selectedSection,
                        text: $text
                    )
                }
            }
            .sheet(isPresented: $showVoicePicker) {
                VoicePickerView(
                    language: selectedLanguage,
                    selectedVoice: $selectedVoice
                )
            }
            .sheet(isPresented: $showDocumentPresentation) {
                if let doc = presentationDocument {
                    DocumentPresentationView(
                        document: doc,
                        selectedText: $text,
                        lastReadSectionIndex: doc.id == lastReadDocument?.id ? lastReadSectionIndex : nil,
                        onSectionSelected: { section, index in
                            // Activar reproducción continua automáticamente
                            selectedDocument = doc
                            sectionsQueue = doc.sections
                            currentSectionIndex = index
                            autoPlaySections = true
                            
                            // Si está en modo libro, iniciar pre-carga después de generar el audio actual
                            if bookMode {
                                print("📚 Modo Libro activado - Se pre-cargarán las próximas secciones")
                            }
                        }
                    )
                }
            }
        }
        .onAppear {
            loadAPIKey()
            restoreReadingSession()
            setupAudioCallback()
        }
    }    
    private func setupAudioCallback() {
        audioPlayer.onAudioFinished = { [weak audioPlayer] in
            DispatchQueue.main.async {
                if self.autoPlaySections && !self.sectionsQueue.isEmpty {
                    self.playNextSection()
                }
            }
        }
    }
    
    private func playNextSection() {
        guard !sectionsQueue.isEmpty else {
            autoPlaySections = false
            return
        }
        
        // Guardar progreso antes de avanzar
        saveReadingProgress()
        
        currentSectionIndex += 1
        
        if currentSectionIndex < sectionsQueue.count {
            let nextSection = sectionsQueue[currentSectionIndex]
            if let document = selectedDocument {
                print("📄 Siguiente sección: \(nextSection.title)")
                
                // Verificar si está en caché
                if bookMode, let cachedAudio = getAudioFromCache(for: currentSectionIndex) {
                    print("⚡️ ¡Audio en caché! Transición instantánea")
                    
                    let sectionText = document.getSectionText(nextSection)
                    text = cleanedText(from: sectionText)
                    
                    // Reproducir directamente desde caché
                    audioData = cachedAudio
                    do {
                        audioPlayer.nowPlayingTitle = buildNowPlayingTitle()
                        try audioPlayer.playAudio(data: cachedAudio)
                        print("✅ Reproduciendo desde caché")
                        
                        // Disparar pre-carga de siguientes secciones
                        preloadNextSections()
                    } catch {
                        print("❌ Error reproduciendo caché: \(error.localizedDescription)")
                        errorMessage = error.localizedDescription
                    }
                } else {
                    // No está en caché, generar normalmente
                    let sectionText = document.getSectionText(nextSection)
                    let rawBytes = sectionText.utf8.count
                    text = cleanedText(from: sectionText)
                    let cleanBytes = text.utf8.count
                    
                    print("📊 Texto RAW: \(rawBytes) bytes")
                    print("✨ Texto LIMPIO: \(cleanBytes) bytes")
                    print("♻️ Reducción: \(rawBytes - cleanBytes) bytes")
                    
                    if cleanBytes > 4000 {
                        print("⚠️ ADVERTENCIA: Texto aún > 4000 bytes, se dividirá automáticamente")
                    }
                    
                    // Generar audio de la siguiente sección
                    Task {
                        await generateSectionAudio()
                        
                        // Después de generar, guardar en caché y pre-cargar siguientes
                        if bookMode {
                            let cacheKey = getCacheKey(for: nextSection, index: currentSectionIndex)
                            if let data = audioData {
                                audioCache[cacheKey] = data
                                preloadedSections.insert(currentSectionIndex)
                                print("💾 Audio guardado en caché")
                            }
                            preloadNextSections()
                        }
                    }
                }
            }
        } else {
            // Terminamos todas las secciones
            autoPlaySections = false
            currentSectionIndex = 0
            sectionsQueue = []
        }
    }
    
    private func generateSectionAudio() async {
        isLoading = true
        errorMessage = nil
        audioPlayer.stop()
        audioData = nil
        
        do {
            let service = GoogleTTSService(apiKey: apiKey, useVertex: useVertexVoices)
            service.useSSMLPauses = useSSMLPauses
            
            // Verificar el tamaño del texto y dividir si es necesario
            let textBytes = text.utf8.count
            var data: Data
            
            if textBytes > 4000 {
                // Texto demasiado largo, dividir en chunks
                print("⚠️ Sección larga detectada: \(textBytes) bytes. Dividiendo...")
                let chunks = splitTextIntoChunks(text)
                print("✅ Sección dividida en \(chunks.count) fragmentos")
                
                // Generar audio para cada chunk y combinar
                var allAudioData = Data()
                for (index, chunk) in chunks.enumerated() {
                    print("🔄 Generando fragmento \(index + 1)/\(chunks.count)...")
                    let chunkData = try await service.synthesizeSpeech(
                        text: chunk,
                        language: selectedLanguage,
                        speakingRate: speakingRate,
                        pitch: pitch,
                        voice: selectedVoice
                    )
                    allAudioData.append(chunkData)
                }
                data = allAudioData
                print("✅ Audio de sección combinado exitosamente")
            } else {
                // Texto normal, generar directamente
                data = try await service.synthesizeSpeech(
                    text: text,
                    language: selectedLanguage,
                    speakingRate: speakingRate,
                    pitch: pitch,
                    voice: selectedVoice
                )
            }
            
            await MainActor.run {
                audioData = data
                isLoading = false
                
                // Auto-play the audio
                do {
                    audioPlayer.nowPlayingTitle = buildNowPlayingTitle()
                    try audioPlayer.playAudio(data: data)
                    
                    // Iniciar pre-carga en modo libro
                    if bookMode && !sectionsQueue.isEmpty {
                        print("🔄 Iniciando pre-carga de siguientes secciones...")
                        preloadNextSections()
                    }
                } catch {
                    errorMessage = "Error al reproducir: \(error.localizedDescription)"
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    

    
    // MARK: - Helper para limpiar y dividir texto
    
    private func cleanedText(from text: String) -> String {
        var result = text
        guard !result.isEmpty else { return "" }
        
        // Normalize newlines
        result = result.replacingOccurrences(of: "\r\n", with: "\n")
        result = result.replacingOccurrences(of: "\r", with: "\n")
        
        // Remove soft hyphen
        result = result.replacingOccurrences(of: "\u{00AD}", with: "")
        
        // Remove URLs
        if let urlRegex = try? NSRegularExpression(pattern: "(https?://|www\\.)\\S+", options: [.caseInsensitive]) {
            result = urlRegex.stringByReplacingMatches(in: result, options: [], range: NSRange(location: 0, length: (result as NSString).length), withTemplate: "")
        }
        
        // Remove page markers
        let pagePatterns = ["\\bP[aá]gina\\s+\\d+\\b", "\\bPage\\s+\\d+\\b", "\\bP[aá]g\\.?\\s+\\d+\\b"]
        for pattern in pagePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                result = regex.stringByReplacingMatches(in: result, options: [], range: NSRange(location: 0, length: (result as NSString).length), withTemplate: "")
            }
        }
        
        // Join hyphenated line breaks
        result = result.replacingOccurrences(of: "-\n", with: "")
        
        // Replace newlines with spaces
        result = result.replacingOccurrences(of: "\n", with: " ")
        
        // Collapse multiple spaces
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func splitTextIntoChunks(_ text: String, maxBytes: Int = 4000) -> [String] {
        // Usar 4500 en lugar de 5000 para dejar margen de seguridad
        var chunks: [String] = []
        var currentChunk = ""
        
        // Dividir por oraciones (puntos)
        let sentences = text.components(separatedBy: ". ")
        
        for sentence in sentences {
            let sentenceWithPeriod = sentence + ". "
            let testChunk = currentChunk + sentenceWithPeriod
            
            // Verificar el tamaño en bytes
            if testChunk.utf8.count <= maxBytes {
                currentChunk = testChunk
            } else {
                // Si la oración sola es más grande que maxBytes, dividirla por palabras
                if sentenceWithPeriod.utf8.count > maxBytes {
                    let words = sentenceWithPeriod.components(separatedBy: " ")
                    for word in words {
                        let testWord = currentChunk + word + " "
                        if testWord.utf8.count <= maxBytes {
                            currentChunk = testWord
                        } else {
                            if !currentChunk.isEmpty {
                                chunks.append(currentChunk.trimmingCharacters(in: .whitespaces))
                            }
                            currentChunk = word + " "
                        }
                    }
                } else {
                    // Guardar el chunk actual y empezar uno nuevo
                    if !currentChunk.isEmpty {
                        chunks.append(currentChunk.trimmingCharacters(in: .whitespaces))
                    }
                    currentChunk = sentenceWithPeriod
                }
            }
        }
        
        // Agregar el último chunk
        if !currentChunk.isEmpty {
            chunks.append(currentChunk.trimmingCharacters(in: .whitespaces))
        }
        
        return chunks.isEmpty ? [text] : chunks
    }
    
    private func generateSpeech() {
        isLoading = true
        errorMessage = nil
        analysisResult = nil
        audioPlayer.stop()
        audioData = nil
        
        Task {
            do {
                var finalRate = speakingRate
                var finalPitch = pitch
                
                // Análisis de texto si está activado
                if useNaturalAnalysis && !text.isEmpty && !apiKey.isEmpty {
                    let nlService = NaturalLanguageService(apiKey: apiKey)
                    let analysis = try await nlService.analyzeText(text)
                    
                    // Obtener parámetros sugeridos
                    let suggestedParams = nlService.getSpeechParameters(from: analysis)
                    finalRate = suggestedParams.rate
                    finalPitch = suggestedParams.pitch
                    
                    // Generar resumen del análisis
                    let enhancements = nlService.getSSMLEnhancements(from: analysis)
                    await MainActor.run {
                        analysisResult = """
                        📊 Análisis de Texto:
                        • Sentimiento: \(String(format: "%.2f", analysis.sentiment.score)) (magnitud: \(String(format: "%.2f", analysis.sentiment.magnitude)))
                        • Entidades detectadas: \(analysis.entities.count)
                        • Velocidad ajustada: \(String(format: "%.2f", finalRate))x
                        • Tono ajustado: \(String(format: "%.1f", finalPitch))
                        
                        \(enhancements)
                        """
                    }
                }
                
                let service = GoogleTTSService(apiKey: apiKey, useVertex: useVertexVoices)
                service.useSSMLPauses = useSSMLPauses
                
                // Verificar el tamaño del texto y dividir si es necesario
                let textBytes = text.utf8.count
                var data: Data
                
                if textBytes > 4000 {
                    // Texto demasiado largo, dividir en chunks
                    print("⚠️ Texto largo detectado: \(textBytes) bytes. Dividiendo...")
                    let chunks = splitTextIntoChunks(text)
                    print("✅ Texto dividido en \(chunks.count) fragmentos")
                    
                    // Generar audio para cada chunk y combinar
                    var allAudioData = Data()
                    for (index, chunk) in chunks.enumerated() {
                        print("🔄 Generando fragmento \(index + 1)/\(chunks.count)...")
                        let chunkData = try await service.synthesizeSpeech(
                            text: chunk,
                            language: selectedLanguage,
                            speakingRate: finalRate,
                            pitch: finalPitch,
                            voice: selectedVoice
                        )
                        allAudioData.append(chunkData)
                    }
                    data = allAudioData
                    print("✅ Audio combinado exitosamente")
                } else {
                    // Texto normal, generar directamente
                    data = try await service.synthesizeSpeech(
                        text: text,
                        language: selectedLanguage,
                        speakingRate: finalRate,
                        pitch: finalPitch,
                        voice: selectedVoice
                    )
                }
                
                await MainActor.run {
                    audioData = data
                    isLoading = false
                    
                    // Auto-play the audio
                    do {
                        audioPlayer.nowPlayingTitle = buildNowPlayingTitle()
                        try audioPlayer.playAudio(data: data)
                    } catch {
                        errorMessage = "Error al reproducir: \(error.localizedDescription)"
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Reading Progress Functions
    
    // MARK: - Modo Libro: Pre-generación y Caché
    
    private func getCacheKey(for section: DocumentSection, index: Int) -> String {
        guard let docId = selectedDocument?.id.uuidString else { return "" }
        let voiceKey = selectedVoice?.id ?? "AUTO-\(selectedLanguage.code)"
        return "\(docId)_\(voiceKey)_section_\(index)"
    }
    
    private func preloadNextSections() {
        guard bookMode, !isPreloading else { return }
        guard let document = selectedDocument else { return }
        guard document.hasSections else { return }
        
        isPreloading = true
        
        Task {
            let sectionsToPreload = 3 // Pre-cargar 3 secciones adelante
            let startIndex = currentSectionIndex + 1
            let endIndex = min(startIndex + sectionsToPreload, sectionsQueue.count)
            
            print("📚 Modo Libro: Pre-cargando secciones \(startIndex + 1) a \(endIndex)")
            
            for i in startIndex..<endIndex {
                // Si ya está en caché, saltar
                if preloadedSections.contains(i) {
                    print("✅ Sección \(i + 1) ya en caché")
                    continue
                }
                
                let section = sectionsQueue[i]
                let cacheKey = getCacheKey(for: section, index: i)
                
                // Verificar si ya existe en memoria
                if audioCache[cacheKey] != nil {
                    await MainActor.run {
                        preloadedSections.insert(i)
                    }
                    continue
                }
                
                // Generar audio de la sección
                do {
                    print("🔄 Pre-generando sección \(i + 1): \(section.title)")
                    let sectionText = document.getSectionText(section)
                    let cleanText = cleanedText(from: sectionText)
                    
                    let service = GoogleTTSService(apiKey: apiKey, useVertex: useVertexVoices)
                    service.useSSMLPauses = useSSMLPauses
                    let textBytes = cleanText.utf8.count
                    var audioData: Data
                    
                    if textBytes > 4000 {
                        // Dividir en chunks
                        let chunks = splitTextIntoChunks(cleanText)
                        var allAudioData = Data()
                        for chunk in chunks {
                            let chunkData = try await service.synthesizeSpeech(
                                text: chunk,
                                language: selectedLanguage,
                                speakingRate: speakingRate,
                                pitch: pitch,
                                voice: selectedVoice
                            )
                            allAudioData.append(chunkData)
                        }
                        audioData = allAudioData
                    } else {
                        audioData = try await service.synthesizeSpeech(
                            text: cleanText,
                            language: selectedLanguage,
                            speakingRate: speakingRate,
                            pitch: pitch,
                            voice: selectedVoice
                        )
                    }
                    
                    // Guardar en caché
                    await MainActor.run {
                        audioCache[cacheKey] = audioData
                        preloadedSections.insert(i)
                        preloadProgress = Double(preloadedSections.count) / Double(sectionsQueue.count)
                        print("✅ Sección \(i + 1) pre-cargada y guardada en caché")
                    }
                    
                } catch {
                    print("❌ Error pre-cargando sección \(i + 1): \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                isPreloading = false
                print("📚 Pre-carga completada. Secciones en caché: \(preloadedSections.count)")
            }
        }
    }
    
    private func getAudioFromCache(for index: Int) -> Data? {
        guard let section = sectionsQueue.indices.contains(index) ? sectionsQueue[index] : nil else {
            return nil
        }
        let cacheKey = getCacheKey(for: section, index: index)
        return audioCache[cacheKey]
    }
    
    private func saveReadingProgress() {
        // Guardar el documento actual
        lastReadDocument = selectedDocument

        // Guardar el índice de sección actual
        lastReadSectionIndex = currentSectionIndex

        // Guardar la posición de reproducción
        lastPlaybackPosition = audioPlayer.currentTime

        // Habilitar el botón de continuar
        canContinueReading = true

        persistReadingSession()
    }

    private func persistReadingSession() {
        let defaults = UserDefaults.standard

        if let document = selectedDocument {
            defaults.set(document.id.uuidString, forKey: "NaturllyLastReadDocumentID")
            defaults.set(document.name, forKey: "NaturllyLastReadDocumentName")
        } else {
            defaults.removeObject(forKey: "NaturllyLastReadDocumentID")
            defaults.removeObject(forKey: "NaturllyLastReadDocumentName")
        }

        defaults.set(lastReadSectionIndex, forKey: "NaturllyLastReadSectionIndex")
        defaults.set(lastPlaybackPosition, forKey: "NaturllyLastPlaybackPosition")
        defaults.set(canContinueReading, forKey: "NaturllyCanContinueReading")
        defaults.set(selectedLanguage.code, forKey: "NaturllyLastLanguageCode")
        defaults.set(bookMode, forKey: "NaturllyBookMode")
        defaults.set(useVertexVoices, forKey: "UseVertexVoices")

        if let voice = selectedVoice {
            defaults.set(voice.id, forKey: "NaturllyLastVoiceID")
            defaults.set(voice.languageCode, forKey: "NaturllyLastVoiceLanguageCode")
            defaults.set(voice.name, forKey: "NaturllyLastVoiceName")
        } else {
            defaults.removeObject(forKey: "NaturllyLastVoiceID")
            defaults.removeObject(forKey: "NaturllyLastVoiceLanguageCode")
            defaults.removeObject(forKey: "NaturllyLastVoiceName")
        }
    }

    private func restoreReadingSession() {
        let defaults = UserDefaults.standard

        if let languageCode = defaults.string(forKey: "NaturllyLastLanguageCode") {
            if let language = TTSLanguage.availableLanguages.first(where: { $0.code == languageCode }) {
                selectedLanguage = language
            }
        }

        if let voiceID = defaults.string(forKey: "NaturllyLastVoiceID"),
           let languageCode = defaults.string(forKey: "NaturllyLastVoiceLanguageCode") {
            selectedVoice = TTSVoice.getVoices(for: languageCode).first(where: { $0.id == voiceID })
        } else {
            selectedVoice = nil
        }

        if defaults.object(forKey: "NaturllyBookMode") != nil {
            bookMode = defaults.bool(forKey: "NaturllyBookMode")
        }

        if defaults.object(forKey: "NaturllyLastReadDocumentID") != nil,
           let documentID = defaults.string(forKey: "NaturllyLastReadDocumentID") {
            if let savedDocument = documents.first(where: { $0.id.uuidString == documentID }) {
                selectedDocument = savedDocument
                lastReadDocument = savedDocument
                canContinueReading = defaults.bool(forKey: "NaturllyCanContinueReading")
                lastReadSectionIndex = defaults.integer(forKey: "NaturllyLastReadSectionIndex")
                lastPlaybackPosition = defaults.double(forKey: "NaturllyLastPlaybackPosition")

                if savedDocument.hasSections && !savedDocument.sections.isEmpty {
                    sectionsQueue = savedDocument.sections
                    currentSectionIndex = min(max(lastReadSectionIndex, 0), sectionsQueue.count - 1)
                    if currentSectionIndex >= 0 {
                        let section = sectionsQueue[currentSectionIndex]
                        text = cleanedText(from: savedDocument.getSectionText(section))
                    }
                }
            }
        }
    }

    private func continueReading() {
        guard let document = lastReadDocument else { return }

        // Restaurar el documento
        selectedDocument = document

        // Si tiene secciones, restaurar la cola y el índice
        if document.hasSections && !document.sections.isEmpty {
            sectionsQueue = document.sections
            currentSectionIndex = lastReadSectionIndex

            // Cargar el texto de la sección actual
            if currentSectionIndex < sectionsQueue.count {
                let section = sectionsQueue[currentSectionIndex]
                let rawText = document.getSectionText(section)
                // Limpiar el texto antes de generar audio
                text = cleanedText(from: rawText)

                // Habilitar reproducción continua
                autoPlaySections = true
            }
        } else {
            // Documento sin secciones, cargar todo el texto
            text = cleanedText(from: document.text)
        }

        // Generar audio y reanudar desde la posición guardada
        Task {
            await generateSpeech()

            // Después de generar, buscar la posición guardada
            if let data = audioData, lastPlaybackPosition > 0 {
                audioPlayer.nowPlayingTitle = buildNowPlayingTitle()
                try? audioPlayer.playAudio(data: data)
                audioPlayer.seek(to: lastPlaybackPosition)
            }
        }
    }
    
        private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func loadAPIKey() {
        if let key = UserDefaults.standard.string(forKey: "GoogleTTSAPIKey"), !key.isEmpty {
            apiKey = key
        } else if !APIConfig.defaultGoogleTTSAPIKey.isEmpty {
            // Persist default key so the rest of the app treats it as configured
            UserDefaults.standard.set(APIConfig.defaultGoogleTTSAPIKey, forKey: "GoogleTTSAPIKey")
            apiKey = APIConfig.defaultGoogleTTSAPIKey
        } else {
            apiKey = ""
        }
        
        // Cargar preferencia de análisis
        useNaturalAnalysis = UserDefaults.standard.bool(forKey: "UseNaturalAnalysis")
        
        // Cargar preferencia de pausas SSML (por defecto true)
        if UserDefaults.standard.object(forKey: "UseSSMLPauses") != nil {
            useSSMLPauses = UserDefaults.standard.bool(forKey: "UseSSMLPauses")
        } else {
            useSSMLPauses = true // Activado por defecto
        }
    }
    
    private func saveAnalysisPreference() {
        UserDefaults.standard.set(useNaturalAnalysis, forKey: "UseNaturalAnalysis")
    }
    
    private func saveSSMLPreference() {
        UserDefaults.standard.set(useSSMLPauses, forKey: "UseSSMLPauses")
    }
    
    private func buildNowPlayingTitle() -> String {
        if let document = selectedDocument {
            if currentSectionIndex < sectionsQueue.count {
                let section = sectionsQueue[currentSectionIndex]
                return "\(document.name) — \(section.title)"
            } else {
                return document.name
            }
        } else {
            return "Texto libre"
        }
    }
}

struct SettingsView: View {
    @Binding var apiKey: String
    @Binding var useVertexVoices: Bool
    @Environment(\.dismiss) var dismiss
    @State private var inputKey: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("AIzaSy...", text: $inputKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("API Key de Google Cloud")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Para obtener tu API Key:")
                        Text("1. Ve a console.cloud.google.com")
                        Text("2. Habilita la API de Text-to-Speech")
                        Text("3. Crea credenciales (API Key)")
                    }
                    .font(.caption)
                }
                
                Section {
                    Toggle("Usar voces de Vertex AI (v1beta1)", isOn: $useVertexVoices)
                    
                    Button("Guardar") {
                        UserDefaults.standard.set(inputKey, forKey: "GoogleTTSAPIKey")
                        UserDefaults.standard.set(useVertexVoices, forKey: "UseVertexVoices")
                        apiKey = inputKey
                        dismiss()
                    }
                    .disabled(inputKey.isEmpty)
                    
                    Button("Cancelar", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .navigationTitle("Configuración")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            inputKey = apiKey
            if inputKey.isEmpty, !APIConfig.defaultGoogleTTSAPIKey.isEmpty {
                inputKey = APIConfig.defaultGoogleTTSAPIKey
            }
        }
    }
}
// MARK: - Document List View
struct DocumentListView: View {
    @Binding var documents: [Document]
    @Binding var selectedDocument: Document?
    @Binding var text: String
    @Binding var isPresented: Bool
    @Binding var selectedSection: DocumentSection?
    @Binding var showSections: Bool
    
    let onPresentDocument: (Document) -> Void
    var body: some View {
        NavigationView {
            List {
                if documents.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundColor(.gray)
                        Text("No hay documentos")
                            .font(.headline)
                        Text("Importa archivos PDF o EPUB para convertirlos a audio")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    ForEach(documents) { document in
                        VStack(alignment: .leading, spacing: 0) {
                            DocumentRow(document: document)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedDocument = document
                                    selectedSection = nil  // Reset section when selecting document
                                    text = document.text
                                    isPresented = false
                                }
                            
                            // Show index button if document has sections
                            if document.hasSections {
                                Button(action: {
                                    onPresentDocument(document)
                                }) {
                                    HStack {
                                        Image(systemName: "doc.text.image")
                                            .foregroundColor(.blue)
                                        Text("Ver Presentación")
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.05))
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteDocuments)
                }
            }
            .navigationTitle("Mis Documentos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") {
                        isPresented = false
                    }
                }
                
                if !documents.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                }
            }
        }
    }
    
    private func deleteDocuments(at offsets: IndexSet) {
        documents.remove(atOffsets: offsets)
    }
}

// MARK: - Document Row
struct DocumentRow: View {
    let document: Document
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: document.type.icon)
                .font(.system(size: 32))
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(document.name)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack {
                    if let pageCount = document.pageCount {
                        Label("\(pageCount) páginas", systemImage: "doc.plaintext")
                            .font(.caption)
                    }
                    Label("\(document.characterCount) caracteres", systemImage: "textformat.size")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                
                Text(document.preview)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.top, 4)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.caption)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ContentView().environmentObject(AudioPlayerManager())
}
