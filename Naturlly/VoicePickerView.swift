//
//  VoicePickerView.swift
//  Naturlly TTS
//
//  View for selecting Google TTS voices
//

import SwiftUI

enum VoiceProvider: String, CaseIterable, Identifiable {
    case google = "Google TTS"
    case vertex = "Vertex AI"
    
    var id: String { rawValue }
}

struct VoicePickerView: View {
    let language: TTSLanguage
    @Binding var selectedVoice: TTSVoice?
    @Environment(\.dismiss) var dismiss
    
    @State private var provider: VoiceProvider = .google
    @State private var isLoading: Bool = false
    @State private var dynamicVoices: [TTSVoice] = []
    @State private var errorMessage: String? = nil
    
    private var availableVoices: [TTSVoice] {
        dynamicVoices.isEmpty ? TTSVoice.getVoices(for: language.code) : dynamicVoices
    }
    
    private var groupedVoices: [(VoiceType, [TTSVoice])] {
        let grouped = Dictionary(grouping: availableVoices) { $0.type }
        return grouped.sorted { $0.key.rawValue < $1.key.rawValue }
            .map { ($0.key, $0.value.sorted { $0.name < $1.name }) }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("Proveedor", selection: $provider) {
                    ForEach(VoiceProvider.allCases) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                List {
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(1.5)
                            Text("Cargando voces...")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .listRowInsets(EdgeInsets())
                    } else if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .listRowInsets(EdgeInsets())
                    } else if availableVoices.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "waveform.circle")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text("No hay voces disponibles")
                                .font(.headline)
                            Text("No se encontraron voces para este idioma")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        ForEach(groupedVoices, id: \.0) { voiceType, voices in
                            Section {
                                ForEach(voices) { voice in
                                    VoiceRowView(
                                        voice: voice,
                                        isSelected: selectedVoice?.id == voice.id
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedVoice = voice
                                        dismiss()
                                    }
                                }
                            } header: {
                                HStack {
                                    Text(voiceType.displayName)
                                    Spacer()
                                    if voiceType == .wavenet || voiceType == .neural2 {
                                        Image(systemName: "star.fill")
                                            .font(.caption)
                                            .foregroundColor(.yellow)
                                    }
                                }
                            } footer: {
                                if voiceType == .wavenet {
                                    Text("WaveNet: Calidad superior con sonido más natural")
                                        .font(.caption)
                                } else if voiceType == .neural2 {
                                    Text("Neural2: Última generación con máxima naturalidad")
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Seleccionar Voz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
                
                if selectedVoice != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Por defecto") {
                            selectedVoice = nil
                            dismiss()
                        }
                    }
                }
            }
            .task {
                await fetchVoices()
            }
            .onChange(of: provider) { _ in
                Task {
                    await fetchVoices()
                }
            }
        }
    }
    
    private func fetchVoices() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        do {
            let apiKey = UserDefaults.standard.string(forKey: "GoogleTTSAPIKey") ?? ""
            let voices = try await VoiceService.shared.fetchVoices(apiKey: apiKey, languageCode: language.code, useVertex: provider == .vertex)
            await MainActor.run {
                dynamicVoices = voices
                isLoading = false
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                dynamicVoices = []
                isLoading = false
                errorMessage = "Error al cargar voces: \(error.localizedDescription)"
            }
        }
    }
}

struct VoiceRowView: View {
    let voice: TTSVoice
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Text(voice.gender == .male ? "♂" : (voice.gender == .female ? "♀" : "⚪"))
                .font(.title3)
                .foregroundColor(voice.gender == .male ? .blue : .pink)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(voice.name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                HStack(spacing: 8) {
                    Text(voice.gender == .male ? "Masculina" : "Femenina")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if voice.type == .wavenet || voice.type == .neural2 {
                        Label(voice.type.displayName, systemImage: "sparkles")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}
