//
//  NaturllyApp.swift
//  Naturlly TTS
//
//  Created on November 26, 2025.
//

import SwiftUI

@main
struct NaturllyApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var audioManager = AudioPlayerManager()
    @StateObject private var lang = LanguageSettings()
    @State private var draftSaveTask: Task<Void, Never>?
    @State private var documents: [Document] = []
    @State private var selectedDocument: Document?
    @State private var text: String = ""
    @State private var selectedSection: DocumentSection?
    @State private var showSections = false
    @State private var showSettings = false
    @AppStorage("apiKey") private var apiKey: String = ""
    @AppStorage("useVertexVoices") private var useVertexVoices: Bool = false
    @AppStorage("draftTextBackup") private var draftTextBackup: String = ""

    private var libraryURL: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("library.json")
    }

    private var draftURL: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("draftText.txt")
    }
    
    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView(
                    documents: $documents,
                    selectedDocument: $selectedDocument,
                    text: $text,
                    selectedSection: $selectedSection,
                    showSections: $showSections
                )
                    .tabItem {
                        Label(String(localized: "tab.tts"), systemImage: "waveform")
                    }
                
                LibraryView(
                    documents: $documents,
                    selectedDocument: $selectedDocument,
                    text: $text,
                    selectedSection: $selectedSection,
                    showSections: $showSections
                )
                    .tabItem {
                        Label(String(localized: "tab.library"), systemImage: "books.vertical.fill")
                    }
                    .badge(documents.isEmpty ? 0 : documents.count)
            }
            .environmentObject(audioManager)
            .environmentObject(lang)
            .environment(\.locale, lang.effectiveLocale ?? .current)
            .task {
                loadLibrary()
                loadDraftText()
            }
            .onChange(of: documents) { _, _ in
                saveLibrary()
            }
            .onChange(of: text) { _, newValue in
                scheduleDraftSave(newValue)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .inactive || newPhase == .background {
                    draftSaveTask?.cancel()
                    saveLibrary()
                    saveDraftText(text)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(apiKey: $apiKey, useVertexVoices: $useVertexVoices)
                    .environmentObject(lang)
            }
        }
    }

    // MARK: - Persistence
    private func loadLibrary() {
        do {
            let data = try Data(contentsOf: libraryURL)
            documents = try JSONDecoder().decode([Document].self, from: data)
        } catch {
            // No library yet or failed to decode; start empty
            documents = []
        }
    }

    private func saveLibrary() {
        do {
            let data = try JSONEncoder().encode(documents)
            try data.write(to: libraryURL, options: .atomic)
        } catch {
            print("Error guardando biblioteca: \(error.localizedDescription)")
        }
    }

    private func loadDraftText() {
        guard selectedDocument == nil else { return }
        if let data = try? Data(contentsOf: draftURL),
           let value = String(data: data, encoding: .utf8) {
            text = value
            if draftTextBackup != value {
                draftTextBackup = value
            }
            return
        }

        if !draftTextBackup.isEmpty {
            text = draftTextBackup
        }
    }

    private func saveDraftText(_ value: String) {
        // Keep an immediate backup in UserDefaults in case file write is interrupted.
        if draftTextBackup != value {
            draftTextBackup = value
        }

        do {
            let data = value.data(using: .utf8) ?? Data()
            try data.write(to: draftURL, options: .atomic)
        } catch {
            print("Error guardando borrador: \(error.localizedDescription)")
        }
    }

    private func scheduleDraftSave(_ value: String) {
        // Persist lightweight backup immediately; file save stays debounced.
        if draftTextBackup != value {
            draftTextBackup = value
        }

        draftSaveTask?.cancel()
        draftSaveTask = Task {
            // Debounce to avoid writing on every keystroke.
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            saveDraftText(value)
        }
    }
}

