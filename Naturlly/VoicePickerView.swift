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
    
    private func favoritesKey(for languageCode: String) -> String { "FavoriteVoices_\(languageCode)" }
    
    private func loadFavorites(for languageCode: String) -> Set<String> {
        let key = favoritesKey(for: languageCode)
        if let arr = UserDefaults.standard.array(forKey: key) as? [String] {
            return Set(arr)
        }
        return []
    }
    
    private func saveFavorites(_ favorites: Set<String>, for languageCode: String) {
        let key = favoritesKey(for: languageCode)
        UserDefaults.standard.set(Array(favorites), forKey: key)
    }
    
    private var availableVoices: [TTSVoice] {
        let base = dynamicVoices.isEmpty ? TTSVoice.getVoices(for: language.code) : dynamicVoices
        let favs = loadFavorites(for: language.code)
        return base.map { v in
            var vv = v
            vv.isFavorite = favs.contains(v.id)
            return vv
        }
    }
    
    private var groupedVoices: [(VoiceType, [TTSVoice])] {
        {
            typealias Group = (key: VoiceType, voices: [TTSVoice])
            let voices: [TTSVoice] = availableVoices
            let groupedDict: [VoiceType: [TTSVoice]] = Dictionary(grouping: voices, by: { (voice: TTSVoice) -> VoiceType in
                voice.type
            })

            let sortedKeys: [VoiceType] = groupedDict.keys.sorted(by: { (lhs: VoiceType, rhs: VoiceType) -> Bool in
                lhs.rawValue < rhs.rawValue
            })

            var result: [Group] = []
            result.reserveCapacity(sortedKeys.count)

            for key in sortedKeys {
                let arr: [TTSVoice] = groupedDict[key] ?? []
                let sortedArr: [TTSVoice] = arr.sorted(by: { (a: TTSVoice, b: TTSVoice) -> Bool in
                    if a.isFavorite != b.isFavorite {
                        return a.isFavorite && !b.isFavorite
                    }
                    return a.name < b.name
                })
                result.append((key: key, voices: sortedArr))
            }

            // Return as array of tuples to satisfy the property type
            var tuples: [(VoiceType, [TTSVoice])] = []
            tuples.reserveCapacity(result.count)
            for item in result {
                tuples.append((item.key, item.voices))
            }
            return tuples
        }()
    }
    
    private func toggleFavorite(for voice: TTSVoice) {
        var favs = loadFavorites(for: language.code)
        if favs.contains(voice.id) {
            favs.remove(voice.id)
        } else {
            favs.insert(voice.id)
        }
        saveFavorites(favs, for: language.code)

        if let idx = dynamicVoices.firstIndex(where: { $0.id == voice.id && $0.languageCode == voice.languageCode }) {
            dynamicVoices[idx].isFavorite = favs.contains(voice.id)
        } else {
            let all = availableVoices
            if let sidx = all.firstIndex(where: { $0.id == voice.id && $0.languageCode == voice.languageCode }) {
                var updated = all[sidx]
                updated.isFavorite = favs.contains(voice.id)
                dynamicVoices = all.enumerated().map { (index, element) in index == sidx ? updated : element }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("Proveedor", selection: $provider) {
                    ForEach(VoiceProvider.allCases) { (provider: VoiceProvider) in
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
                            Text(String(localized: "voice_picker.loading"))
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
                            Text(String(localized: "voice_picker.empty"))
                                .font(.headline)
                            Text(String(localized: "voice_picker.empty_desc"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        // Favorites section on top
                        let favorites = availableVoices.filter { $0.isFavorite }
                        if !favorites.isEmpty {
                            Section(String(localized: "voice_picker.favorites")) {
                                ForEach(favorites) { voice in
                                    VoiceRowView(
                                        voice: voice,
                                        isSelected: selectedVoice?.id == voice.id,
                                        onToggleFavorite: { toggleFavorite(for: voice) }
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedVoice = voice
                                        dismiss()
                                    }
                                }
                            }
                        }
                        
                        ForEach(groupedVoices, id: \.0) { pair in
                            let voiceType = pair.0
                            let voices = pair.1
                            Section {
                                ForEach(voices.filter { !$0.isFavorite }) { voice in
                                    VoiceRowView(
                                        voice: voice,
                                        isSelected: selectedVoice?.id == voice.id,
                                        onToggleFavorite: { toggleFavorite(for: voice) }
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
                                    Text(String(localized: "voice_picker.wavenet_footer"))
                                        .font(.caption)
                                } else if voiceType == .neural2 {
                                    Text(String(localized: "voice_picker.neural2_footer"))
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "voice_picker.nav_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "btn.close"), action: { dismiss() })
                }
                
                if selectedVoice != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(String(localized: "btn.default"), action: { selectedVoice = nil; dismiss() })
                    }
                }
            }
            .task {
                await fetchVoices()
            }
            .onChange(of: provider) { _, _ in
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
                let favs = loadFavorites(for: language.code)
                dynamicVoices = voices.map { v in
                    var vv = v
                    vv.isFavorite = favs.contains(v.id)
                    return vv
                }
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
    let onToggleFavorite: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Text(voice.gender == .male ? "♂" : (voice.gender == .female ? "♀" : "⚪"))
                .font(.title3)
                .foregroundColor(voice.gender == .male ? .blue : .pink)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(voice.simpleName)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                    Text(voice.languageCode)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(UIColor.tertiarySystemFill))
                        .cornerRadius(4)
                }
                
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
            
            // Star favorite button
            Button(action: { onToggleFavorite() }) {
                Image(systemName: voice.isFavorite ? "star.fill" : "star")
                    .foregroundColor(voice.isFavorite ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

