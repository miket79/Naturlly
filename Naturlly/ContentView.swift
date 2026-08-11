//
//  ContentView.swift
//  Naturlly TTS
//
//  Main user interface
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var audioPlayer: AudioPlayerManager
    @Binding var documents: [Document]
    @Binding var selectedDocument: Document?
    @Binding var text: String
    @Binding var selectedSection: DocumentSection?
    @Binding var showSections: Bool
    
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
    @State private var showDocumentPicker = false
    @State private var useNaturalAnalysis: Bool = false
    @State private var analysisResult: String?
    @State private var useSSMLPauses: Bool = true
    @State private var presentationDocument: Document?
    @State private var currentSectionIndex: Int = 0
    @State private var autoPlaySections: Bool = false
    @State private var sectionsQueue: [DocumentSection] = []
    @State private var useVertexVoices: Bool = UserDefaults.standard.bool(forKey: "UseVertexVoices")
    @State private var useLongAudioService: Bool = UserDefaults.standard.bool(forKey: APIConfig.useLongAudioServiceKey)
    @State private var backendURL: String = UserDefaults.standard.string(forKey: APIConfig.backendURLKey) ?? APIConfig.defaultBackendURL
    @State private var gcsBucket: String = UserDefaults.standard.string(forKey: APIConfig.gcsBucketKey) ?? APIConfig.defaultGCSBucket
    @State private var progressLoaded: Bool = false
    @AppStorage("draftTextBackup") private var draftTextBackup: String = ""
    
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
        NavigationStack {
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
                                        Text(String(localized: "cv.continue_reading"))
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                    }
                                    
                                    Text(document.name)
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.9))
                                        .lineLimit(1)
                                    
                                    if sectionsQueue.count > 0 && lastReadSectionIndex < sectionsQueue.count {
                                        Text(String(format: String(localized: "cv.section_of"), lastReadSectionIndex + 1, sectionsQueue.count))
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
                                    colors: [Color.cyan, Color.cyan.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(14)
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
                            
                            Text(String(localized: "cv.setup_api_key"))
                                .font(.headline)
                            
                            Text(String(localized: "cv.setup_api_key_desc"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button(action: { showSettings = true }) {
                                Label(String(localized: "cv.setup_btn"), systemImage: "gearshape.fill")
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
                        Button(action: { showDocumentPicker = true }) {
                            Label(String(localized: "cv.import_doc"), systemImage: "doc.badge.plus")
                                .font(.subheadline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.cyan)
                                .cornerRadius(10)
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
                                    Button {
                                        presentationDocument = ensureSections(for: doc)
                                    } label: {
                                        Label(String(localized: "cv.index_btn"), systemImage: "list.bullet.rectangle")
                                            .labelStyle(.titleAndIcon)
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.cyan)
                                    Button(action: {
                                        selectedDocument = nil
                                        text = ""
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                Text(String(format: String(localized: "cv.doc_stats"), doc.characterCount, doc.wordCount))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(red: 0.14, green: 0.16, blue: 0.2))
                            .cornerRadius(12)
                        }
                        
                        // Text Input Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text(selectedDocument != nil ? String(localized: "cv.text_section_title_doc") : String(localized: "cv.text_section_title_free"))
                                .font(.headline)
                            
                            TextEditor(text: $text)
                                .frame(height: 140)
                                .padding(10)
                                .background(Color(red: 0.12, green: 0.13, blue: 0.16))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )

                            if selectedDocument == nil,
                               !draftTextBackup.isEmpty {
                                HStack {
                                    Spacer()
                                    Button {
                                        text = draftTextBackup
                                        selectedSection = nil
                                        showSections = false
                                    } label: {
                                        Label(String(localized: "cv.restore_last"), systemImage: "arrow.clockwise.circle")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.cyan)
                                }
                            }
                        }
                        
                        // Language Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "cv.language"))
                                .font(.headline)
                            
                            Picker(String(localized: "cv.language"), selection: $selectedLanguage) {
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
                                Text(String(localized: "cv.voice"))
                                    .font(.headline)
                                Spacer()
                                if selectedVoice != nil {
                                    Button(String(localized: "btn.default")) {
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
                                            Text("\(voice.gender == .male ? String(localized: "cv.voice_gender_male") : String(localized: "cv.voice_gender_female")) - \(voice.type.displayName)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    } else {
                                        Text(String(localized: "cv.auto_voice"))
                                            .foregroundColor(.primary)
                                        Text(String(localized: "cv.tap_to_choose"))
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
                                        Text(String(localized: "cv.smart_analysis"))
                                            .font(.headline)
                                        Text(String(localized: "cv.smart_analysis_desc"))
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
                                        Text(String(localized: "cv.natural_pauses"))
                                            .font(.headline)
                                        Text(String(localized: "cv.natural_pauses_desc"))
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
                                        Text(String(localized: "cv.speed"))
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
                                        Text(String(localized: "cv.pitch"))
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
                                Text(String(localized: "cv.voice_settings"))
                                    .font(.headline)
                                Spacer()
                                Text(String(format: String(localized: "cv.voice_settings_summary"), String(format: "%.1fx", speakingRate), String(format: "%.0f", pitch)))
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
                                        Text(String(localized: "cv.book_mode"))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        Text(bookMode ? String(localized: "cv.book_mode_preload_on") : String(localized: "cv.book_mode_preload_off"))
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
                                Text(isLoading ? String(localized: "cv.generating") : String(localized: "cv.generate_audio"))
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
                                    
                                    // Section indicator
                                    if !sectionsQueue.isEmpty {
                                        Text(String(format: String(localized: "cv.section_of"), currentSectionIndex + 1, sectionsQueue.count))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    // Play/Pause & Skip Controls
                                    HStack(spacing: 16) {
                                        // Previous section
                                        if !sectionsQueue.isEmpty {
                                            Button {
                                                playPreviousSection()
                                            } label: {
                                                Image(systemName: "backward.end.fill")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(currentSectionIndex > 0 ? .primary : .secondary)
                                            }
                                            .disabled(currentSectionIndex <= 0)
                                        }

                                        Button {
                                            audioPlayer.skipBackward(seconds: 15)
                                        } label: {
                                            Image(systemName: "gobackward.15")
                                                .font(.system(size: 28))
                                                .foregroundColor(.primary)
                                        }

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
                                                // Si hay posición guardada, retomar desde ahí
                                                if lastPlaybackPosition > 0 {
                                                    audioPlayer.seek(to: lastPlaybackPosition)
                                                }
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

                                        Button {
                                            audioPlayer.skipForward(seconds: 15)
                                        } label: {
                                            Image(systemName: "goforward.15")
                                                .font(.system(size: 28))
                                                .foregroundColor(.primary)
                                        }

                                        // Next section
                                        if !sectionsQueue.isEmpty {
                                            Button {
                                                playNextSection()
                                            } label: {
                                                Image(systemName: "forward.end.fill")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(currentSectionIndex < sectionsQueue.count - 1 ? .primary : .secondary)
                                            }
                                            .disabled(currentSectionIndex >= sectionsQueue.count - 1)
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
                                        Text(String(localized: "cv.book_mode_active"))
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
                                            Text(String(format: String(localized: "cv.sections_preloaded"), preloadedSections.count))
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
                                            Text(String(localized: "cv.preloading_sections"))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                        }
                                    }
                                }
                                .padding()
                                .cornerRadius(12)
                                .background(Color.green.opacity(0.1))
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
            .navigationTitle(String(localized: "cv.nav_title"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(
                    apiKey: $apiKey,
                    useVertexVoices: $useVertexVoices
                )
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker(
                    documents: $documents,
                    isPresented: $showDocumentPicker,
                    errorMessage: $errorMessage
                )
            }
            .sheet(isPresented: $showSections) {
                if let document = selectedDocument {
                    DocumentSectionsView(
                        document: document,
                        selectedSection: $selectedSection,
                        text: $text,
                        onSectionSelected: { section, index in
                            if let section, let index {
                                playSelectedSection(document: document, section: section, index: index)
                            } else {
                                // Documento completo: limpiar colas y evitar auto-play de secciones
                                selectedDocument = document
                                sectionsQueue = []
                                currentSectionIndex = 0
                                autoPlaySections = false
                                audioData = nil
                                text = cleanedText(from: document.text)
                                // Opcional: generar audio del documento completo
                                Task { await generateSectionAudio() }
                            }
                        }
                    )
                }
            }
            .sheet(isPresented: $showVoicePicker) {
                VoicePickerView(
                    language: selectedLanguage,
                    selectedVoice: $selectedVoice
                )
            }
            .sheet(item: $presentationDocument) { doc in
                let preparedDoc = ensureSections(for: doc)
                NavigationStack {
                    DocumentPresentationView(
                        document: preparedDoc,
                        selectedText: $text,
                        lastReadSectionIndex: preparedDoc.id == lastReadDocument?.id ? lastReadSectionIndex : nil,
                        onSectionSelected: { section, index in
                            playSelectedSection(document: preparedDoc, section: section, index: index)
                        }
                    )
                }
            }
        }
        .onAppear {
            loadAPIKey()
            setupAudioCallback()
            loadPersistentProgressIfNeeded()
        }
        .onChange(of: text) { _, newValue in
            syncSelectedDocumentTextIfNeeded(newValue)
        }
        .onChange(of: documents) { _, _ in
            loadPersistentProgressIfNeeded()
        }
        .preferredColorScheme(.dark)
        .tint(.cyan)
    }
    
    private func setupAudioCallback() {
        audioPlayer.onAudioFinished = { [self] in
            DispatchQueue.main.async {
                print("onAudioFinished: autoPlay=\(self.autoPlaySections), queueCount=\(self.sectionsQueue.count), currentIndex=\(self.currentSectionIndex)")
                if self.autoPlaySections && !self.sectionsQueue.isEmpty {
                    self.playNextSection()
                }
            }
        }
    }
    
    private func playSelectedSection(document: Document, section: DocumentSection, index: Int) {
        selectedDocument = document
        sectionsQueue = document.sections
        currentSectionIndex = index
        autoPlaySections = true
        text = cleanedText(from: document.getSectionText(section))
        lastPlaybackPosition = 0
        
        // Intentar reproducir desde caché primero
        if let cached = getAudioFromCache(for: index) {
            audioData = cached
            audioPlayer.nowPlayingTitle = buildNowPlayingTitle()
            try? audioPlayer.playAudio(data: cached)
            preloadNextSections()
            return
        }
        
        // Generar la sección seleccionada
        Task {
            await generateSectionAudio()
            if audioData == nil {
                errorMessage = "No se pudo generar audio para la sección seleccionada"
            }
        }
    }
    
    private func playPreviousSection() {
        guard !sectionsQueue.isEmpty, currentSectionIndex > 0 else { return }
        saveReadingProgress()
        currentSectionIndex -= 1
        lastPlaybackPosition = 0
        let prevSection = sectionsQueue[currentSectionIndex]
        guard let document = selectedDocument else { return }
        let sectionText = document.getSectionText(prevSection)
        text = cleanedText(from: sectionText)
        if bookMode, let cachedAudio = getAudioFromCache(for: currentSectionIndex) {
            audioData = cachedAudio
            audioPlayer.nowPlayingTitle = buildNowPlayingTitle()
            try? audioPlayer.playAudio(data: cachedAudio)
            preloadNextSections()
        } else {
            Task {
                await generateSectionAudio()
                if bookMode, let data = audioData {
                    let cacheKey = getCacheKey(for: prevSection, index: currentSectionIndex)
                    audioCache[cacheKey] = data
                    preloadedSections.insert(currentSectionIndex)
                }
            }
        }
    }

    private func playNextSection() {
        print("playNextSection: currentIndex(before)=\(currentSectionIndex), queueCount=\(sectionsQueue.count)")
        guard !sectionsQueue.isEmpty else {
            autoPlaySections = false
            return
        }
        
        // Guardar progreso antes de avanzar
        saveReadingProgress()
        
        currentSectionIndex += 1
        print("playNextSection: currentIndex(after)=\(currentSectionIndex)")
        lastPlaybackPosition = 0
        
        if currentSectionIndex < sectionsQueue.count {
            let nextSection = sectionsQueue[currentSectionIndex]
            if let document = selectedDocument {
                print("📄 Siguiente sección: \(nextSection.title)")
                
                // Verificar si está en caché
                if bookMode, let cachedAudio = getAudioFromCache(for: currentSectionIndex) {
                    print("playNextSection: using cache for index \(currentSectionIndex)")
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
                    print("playNextSection: generating audio for index \(currentSectionIndex)")
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
// Determinar qué servicio usar
                let serviceType: TTSServiceType = useLongAudioService ? .longAudio : .regular
                guard let backendURLObj = URL(string: backendURL) else {
                    throw NSError(domain: "TTSService", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL del backend inválida"])
                }
                
                let service = TTSServiceManager(
                    apiKey: apiKey,
                    backendURL: backendURLObj,
                    gcsBucket: gcsBucket,
                    serviceType: serviceType
                )
                
                // Variables para los parámetros finales (después del análisis)
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
                
                // Verificar el tamaño del texto y dividir si es necesario (solo para servicio regular)
                let textBytes = text.utf8.count
                var data: Data
                
                if serviceType == .regular {
                    let uiLimit = TextChunker.effectiveMaxBytes(base: TextChunker.maxBytes, marginPercent: 5, overheadBytes: 0)
                    
                    if textBytes > uiLimit {
                        // Texto demasiado largo, dividir en chunks
                        print("⚠️ Sección larga detectada: \(textBytes) bytes. Dividiendo...")
                        let chunks = TextChunker.split(text, maxBytes: TextChunker.maxBytes, marginPercent: 5, overheadBytes: 0)
                        print("✅ Sección dividida en \(chunks.count) fragmentos")
                        
                        // Generar audio para cada chunk y combinar
                        var allAudioData = Data()
                        for (index, chunk) in chunks.enumerated() {
                            print("🔄 Generando fragmento \(index + 1)/\(chunks.count)...")
                            let chunkData = try await service.synthesizeSpeech(
                                text: chunk,
                                language: selectedLanguage,
                                speakingRate: finalRate,
                                pitch: finalPitch,
                                voice: selectedVoice,
                                useSSMLPauses: useSSMLPauses
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
                            speakingRate: finalRate,
                            pitch: finalPitch,
                            voice: selectedVoice,
                            useSSMLPauses: useSSMLPauses
                        )
                    }
                } else {
                    // Servicio de audio largo - maneja textos largos automáticamente
                    print("🌐 Usando servicio de audio largo en VM: \(backendURL)")
                    data = try await service.synthesizeSpeech(
                        text: text,
                        language: selectedLanguage,
                        speakingRate: finalRate,
                        pitch: finalPitch,
                        voice: selectedVoice,
                        useSSMLPauses: useSSMLPauses
                    )
                    print("✅ Audio generado exitosamente desde VM")
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
    
    private func generateSpeech() {
        isLoading = true
        errorMessage = nil
        analysisResult = nil
        audioPlayer.stop()
        audioData = nil
        
        // Si hay documento sin índice, genera secciones de respaldo antes de continuar
        if let doc = selectedDocument, !doc.hasSections {
            let prepared = ensureSections(for: doc)
            selectedDocument = prepared
            sectionsQueue = prepared.sections
            if let first = prepared.sections.first {
                text = cleanedText(from: prepared.getSectionText(first))
            }
        }
        
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
                
                let service = GoogleTTSService(apiKey: apiKey)
                service.useSSMLPauses = useSSMLPauses
                
                // Verificar el tamaño del texto y dividir si es necesario
                let textBytes = text.utf8.count
                let uiLimit = TextChunker.effectiveMaxBytes(base: TextChunker.maxBytes, marginPercent: 5, overheadBytes: 0)
                var data: Data
                
                if textBytes > uiLimit {
                    // Texto demasiado largo, dividir en chunks
                    print("⚠️ Texto largo detectado: \(textBytes) bytes. Dividiendo...")
                    let chunks = TextChunker.split(text, maxBytes: TextChunker.maxBytes, marginPercent: 5, overheadBytes: 0)
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
        
        Task(priority: .utility) {
            // Small delay to avoid contention right when a new section starts.
            try? await Task.sleep(nanoseconds: 300_000_000)

            let sectionsToPreload = 1 // Mantener solo 1 sección adelantada para reducir carga
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
                        _ = preloadedSections.insert(i)
                    }
                    continue
                }
                
                // Generar audio de la sección
                do {
                    print("🔄 Pre-generando sección \(i + 1): \(section.title)")
                    let sectionText = document.getSectionText(section)
                    let cleanText = cleanedText(from: sectionText)
                    
                    let service = GoogleTTSService(apiKey: apiKey)
                    service.useSSMLPauses = useSSMLPauses
                    let textBytes = cleanText.utf8.count
                    let uiLimit = TextChunker.effectiveMaxBytes(base: TextChunker.maxBytes, marginPercent: 5, overheadBytes: 0)
                    var audioData: Data
                    
                    if textBytes > uiLimit {
                        // Dividir en chunks
                        let chunks = TextChunker.split(cleanText, maxBytes: TextChunker.maxBytes, marginPercent: 5, overheadBytes: 0)
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

        // Persistir en disco
        savePersistentProgress()
    }
    
    private func continueReading() {
        guard let document = lastReadDocument else { return }
        
        // Verificar que el archivo aún existe
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: document.fileURL.path) else {
            // El archivo ya no existe, mostrar error y limpiar estado
            errorMessage = "El archivo del documento ya no está disponible. Por favor, importa el documento nuevamente."
            canContinueReading = false
            lastReadDocument = nil
            return
        }
        
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
            generateSpeech()
            
            // Después de generar, buscar la posición guardada
            if let data = audioData, lastPlaybackPosition > 0 {
                audioPlayer.nowPlayingTitle = buildNowPlayingTitle()
                try? audioPlayer.playAudio(data: data)
                audioPlayer.seek(to: lastPlaybackPosition)
            }
        }
    }

    // MARK: - Persistencia de progreso
    private var progressURL: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("readingProgress.json")
    }
    
    private struct ReadingProgressRecord: Codable {
        let documentId: UUID
        let sectionIndex: Int
        let playbackTime: TimeInterval
    }
    
    private func savePersistentProgress() {
        guard let docId = lastReadDocument?.id else { return }
        let record = ReadingProgressRecord(
            documentId: docId,
            sectionIndex: lastReadSectionIndex,
            playbackTime: lastPlaybackPosition
        )
        do {
            let data = try JSONEncoder().encode(record)
            try data.write(to: progressURL, options: .atomic)
        } catch {
            print("Error guardando progreso: \(error.localizedDescription)")
        }
    }
    
    private func loadPersistentProgressIfNeeded() {
        guard !progressLoaded else { return }
        do {
            let data = try Data(contentsOf: progressURL)
            let record = try JSONDecoder().decode(ReadingProgressRecord.self, from: data)
            if let doc = documents.first(where: { $0.id == record.documentId }) {
                // Verificar que el archivo aún existe
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: doc.fileURL.path) {
                    lastReadDocument = doc
                    lastReadSectionIndex = record.sectionIndex
                    lastPlaybackPosition = record.playbackTime
                    canContinueReading = true
                } else {
                    // Archivo no existe, limpiar progreso
                    try? fileManager.removeItem(at: progressURL)
                }
            }
            progressLoaded = true
        } catch {
            // No progreso previo o fallo al decodificar
            progressLoaded = true
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

// MARK: - Sección de respaldo para índice vacío
extension ContentView {
    private func ensureSections(for document: Document) -> Document {
        if document.hasSections { return document }
        let fallbackSections = generateFallbackSections(for: document.text)
        var updated = document
        updated.sections = fallbackSections
        replaceDocument(updated)
        return updated
    }
    
    private func generateFallbackSections(for text: String, maxChars: Int = 3200) -> [DocumentSection] {
        guard !text.isEmpty else { return [] }
        var sections: [DocumentSection] = []
        let total = text.count
        var start = 0
        while start < total {
            let end = min(start + maxChars, total)
            let title = "Sección \(sections.count + 1)"
            sections.append(DocumentSection(title: title, startOffset: start, endOffset: end))
            start = end
        }
        return sections
    }
    
    private func replaceDocument(_ document: Document) {
        if let idx = documents.firstIndex(where: { $0.id == document.id }) {
            documents[idx] = document
        }
        if selectedDocument?.id == document.id {
            selectedDocument = document
        }
        if presentationDocument?.id == document.id {
            presentationDocument = document
        }
    }

    private func syncSelectedDocumentTextIfNeeded(_ newText: String) {
        guard let current = selectedDocument else { return }

        // Ignore programmatic text updates while reading by sections/pages.
        // During playback, `text` contains the current section excerpt, not the full document.
        if autoPlaySections || !sectionsQueue.isEmpty || selectedSection != nil {
            return
        }

        guard current.text != newText else { return }

        let updated = Document(
            id: current.id,
            name: current.name,
            type: current.type,
            fileURL: current.fileURL,
            text: newText,
            pageCount: current.pageCount,
            createdAt: current.createdAt,
            sections: current.sections
        )
        replaceDocument(updated)
    }
}

#Preview {
    ContentView(
        documents: .constant([]),
        selectedDocument: .constant(nil),
        text: .constant(""),
        selectedSection: .constant(nil),
        showSections: .constant(false)
    ).environmentObject(AudioPlayerManager())
}

