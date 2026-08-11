//
//  TTSVoice.swift
//  Naturlly TTS
//
//  Voice models for Google Text-to-Speech
//

import Foundation

enum VoiceGender: String, Codable {
    case male = "MALE"
    case female = "FEMALE"
    case neutral = "NEUTRAL"
}

enum VoiceType: String {
    case standard = "Standard"
    case wavenet = "WaveNet"
    case neural2 = "Neural2"
    case studio = "Studio"
    case journey = "Journey"
    case news = "News"
    
    var displayName: String {
        return rawValue
    }
}

struct TTSVoice: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let languageCode: String
    let gender: VoiceGender
    let type: VoiceType
    var isFavorite: Bool = false

    // Nombre simplificado: extrae tipo y sufijo (A, B, C...) y muestra género con icono
    var simpleName: String {
        // Simplify names like "es-ES-Standard-A" -> "Standard A"
        // or "en-US-WaveNet-C" -> "WaveNet C"
        // Keep a fallback to original name if pattern not matched
        let components = name.split(separator: "-").map(String.init)
        let knownTypes = ["Standard", "WaveNet", "Neural2", "Studio", "Journey", "News"]
        if let typeIndex = components.firstIndex(where: { knownTypes.contains($0) }) {
            let rest = components[typeIndex...]
            return rest.joined(separator: " ")
        }
        if components.count >= 3 {
            let rest = components.dropFirst(2)
            return rest.joined(separator: " ")
        }
        return name
    }

    // Nombre para UI: incluye icono de favorito si aplica
    var displayName: String {
        let genderIcon = gender == .male ? "♂" : (gender == .female ? "♀" : "⚪")
        let favorite = isFavorite ? "★ " : ""
        return "\(favorite)\(genderIcon) \(simpleName)"
    }

    enum CodingKeys: String, CodingKey {
        case id, name, languageCode, gender, isFavorite
    }

    init(id: String, name: String, languageCode: String, gender: VoiceGender, type: VoiceType, isFavorite: Bool = false) {
        self.id = id
        self.name = name
        self.languageCode = languageCode
        self.gender = gender
        self.type = type
        self.isFavorite = isFavorite
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        languageCode = try container.decode(String.self, forKey: .languageCode)
        gender = try container.decode(VoiceGender.self, forKey: .gender)
        isFavorite = (try? container.decode(Bool.self, forKey: .isFavorite)) ?? false

        // Determine type from name
        if name.contains("WaveNet") {
            type = .wavenet
        } else if name.contains("Neural2") {
            type = .neural2
        } else if name.contains("Studio") {
            type = .studio
        } else if name.contains("Journey") {
            type = .journey
        } else if name.contains("News") {
            type = .news
        } else {
            type = .standard
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(languageCode, forKey: .languageCode)
        try container.encode(gender, forKey: .gender)
        try container.encode(isFavorite, forKey: .isFavorite)
    }
}

// MARK: - Voice Collections by Language

extension TTSVoice {
    static let spanishVoices: [TTSVoice] = [
        // Standard
        TTSVoice(id: "es-ES-Standard-A", name: "es-ES-Standard-A", languageCode: "es-ES", gender: .female, type: .standard),
        TTSVoice(id: "es-ES-Standard-B", name: "es-ES-Standard-B", languageCode: "es-ES", gender: .male, type: .standard),
        TTSVoice(id: "es-ES-Standard-C", name: "es-ES-Standard-C", languageCode: "es-ES", gender: .female, type: .standard),
        TTSVoice(id: "es-ES-Standard-D", name: "es-ES-Standard-D", languageCode: "es-ES", gender: .female, type: .standard),
        // WaveNet
        TTSVoice(id: "es-ES-WaveNet-B", name: "es-ES-WaveNet-B", languageCode: "es-ES", gender: .male, type: .wavenet),
        TTSVoice(id: "es-ES-WaveNet-C", name: "es-ES-WaveNet-C", languageCode: "es-ES", gender: .female, type: .wavenet),
        TTSVoice(id: "es-ES-WaveNet-D", name: "es-ES-WaveNet-D", languageCode: "es-ES", gender: .female, type: .wavenet),
        TTSVoice(id: "es-ES-Neural2-A", name: "es-ES-Neural2-A", languageCode: "es-ES", gender: .female, type: .neural2),
        TTSVoice(id: "es-ES-Neural2-B", name: "es-ES-Neural2-B", languageCode: "es-ES", gender: .male, type: .neural2),
        TTSVoice(id: "es-ES-Neural2-C", name: "es-ES-Neural2-C", languageCode: "es-ES", gender: .female, type: .neural2),
    ]
    
    static let spanishLatinVoices: [TTSVoice] = [
        // Español US (Latino genérico)
        TTSVoice(id: "es-US-Standard-A", name: "es-US-Standard-A", languageCode: "es-US", gender: .female, type: .standard),
        TTSVoice(id: "es-US-Standard-B", name: "es-US-Standard-B", languageCode: "es-US", gender: .male, type: .standard),
        TTSVoice(id: "es-US-Standard-C", name: "es-US-Standard-C", languageCode: "es-US", gender: .male, type: .standard),
        TTSVoice(id: "es-US-WaveNet-A", name: "es-US-WaveNet-A", languageCode: "es-US", gender: .female, type: .wavenet),
        TTSVoice(id: "es-US-WaveNet-B", name: "es-US-WaveNet-B", languageCode: "es-US", gender: .male, type: .wavenet),
        TTSVoice(id: "es-US-WaveNet-C", name: "es-US-WaveNet-C", languageCode: "es-US", gender: .male, type: .wavenet),
        TTSVoice(id: "es-US-Neural2-A", name: "es-US-Neural2-A", languageCode: "es-US", gender: .female, type: .neural2),
        TTSVoice(id: "es-US-Neural2-B", name: "es-US-Neural2-B", languageCode: "es-US", gender: .male, type: .neural2),
        TTSVoice(id: "es-US-Neural2-C", name: "es-US-Neural2-C", languageCode: "es-US", gender: .male, type: .neural2),
        
        // Studio voices (premium)
        TTSVoice(id: "es-US-Studio-B", name: "es-US-Studio-B", languageCode: "es-US", gender: .male, type: .studio),
        
        // Polyglot (voz multilingüe)
        TTSVoice(id: "es-US-Polyglot-1", name: "es-US-Polyglot-1", languageCode: "es-US", gender: .male, type: .neural2),
    ]
    
    static let englishVoices: [TTSVoice] = [
        // Standard
        TTSVoice(id: "en-US-Standard-A", name: "en-US-Standard-A", languageCode: "en-US", gender: .male, type: .standard),
        TTSVoice(id: "en-US-Standard-B", name: "en-US-Standard-B", languageCode: "en-US", gender: .male, type: .standard),
        TTSVoice(id: "en-US-Standard-C", name: "en-US-Standard-C", languageCode: "en-US", gender: .female, type: .standard),
        TTSVoice(id: "en-US-Standard-D", name: "en-US-Standard-D", languageCode: "en-US", gender: .male, type: .standard),
        TTSVoice(id: "en-US-Standard-E", name: "en-US-Standard-E", languageCode: "en-US", gender: .female, type: .standard),
        // WaveNet
        TTSVoice(id: "en-US-WaveNet-A", name: "en-US-WaveNet-A", languageCode: "en-US", gender: .male, type: .wavenet),
        TTSVoice(id: "en-US-WaveNet-B", name: "en-US-WaveNet-B", languageCode: "en-US", gender: .male, type: .wavenet),
        TTSVoice(id: "en-US-WaveNet-C", name: "en-US-WaveNet-C", languageCode: "en-US", gender: .female, type: .wavenet),
        TTSVoice(id: "en-US-WaveNet-D", name: "en-US-WaveNet-D", languageCode: "en-US", gender: .male, type: .wavenet),
        TTSVoice(id: "en-US-WaveNet-E", name: "en-US-WaveNet-E", languageCode: "en-US", gender: .female, type: .wavenet),
        // Neural2
        TTSVoice(id: "en-US-Neural2-A", name: "en-US-Neural2-A", languageCode: "en-US", gender: .male, type: .neural2),
        TTSVoice(id: "en-US-Neural2-C", name: "en-US-Neural2-C", languageCode: "en-US", gender: .female, type: .neural2),
        TTSVoice(id: "en-US-Neural2-D", name: "en-US-Neural2-D", languageCode: "en-US", gender: .male, type: .neural2),
        TTSVoice(id: "en-US-Neural2-E", name: "en-US-Neural2-E", languageCode: "en-US", gender: .female, type: .neural2),
    ]
    
    static let frenchVoices: [TTSVoice] = [
        TTSVoice(id: "fr-FR-Standard-A", name: "fr-FR-Standard-A", languageCode: "fr-FR", gender: .female, type: .standard),
        TTSVoice(id: "fr-FR-Standard-B", name: "fr-FR-Standard-B", languageCode: "fr-FR", gender: .male, type: .standard),
        TTSVoice(id: "fr-FR-Standard-C", name: "fr-FR-Standard-C", languageCode: "fr-FR", gender: .female, type: .standard),
        TTSVoice(id: "fr-FR-Standard-D", name: "fr-FR-Standard-D", languageCode: "fr-FR", gender: .male, type: .standard),
        TTSVoice(id: "fr-FR-WaveNet-A", name: "fr-FR-WaveNet-A", languageCode: "fr-FR", gender: .female, type: .wavenet),
        TTSVoice(id: "fr-FR-WaveNet-B", name: "fr-FR-WaveNet-B", languageCode: "fr-FR", gender: .male, type: .wavenet),
        TTSVoice(id: "fr-FR-WaveNet-C", name: "fr-FR-WaveNet-C", languageCode: "fr-FR", gender: .female, type: .wavenet),
        TTSVoice(id: "fr-FR-Neural2-A", name: "fr-FR-Neural2-A", languageCode: "fr-FR", gender: .female, type: .neural2),
        TTSVoice(id: "fr-FR-Neural2-B", name: "fr-FR-Neural2-B", languageCode: "fr-FR", gender: .male, type: .neural2),
    ]
    
    static let germanVoices: [TTSVoice] = [
        TTSVoice(id: "de-DE-Standard-A", name: "de-DE-Standard-A", languageCode: "de-DE", gender: .female, type: .standard),
        TTSVoice(id: "de-DE-Standard-B", name: "de-DE-Standard-B", languageCode: "de-DE", gender: .male, type: .standard),
        TTSVoice(id: "de-DE-Standard-C", name: "de-DE-Standard-C", languageCode: "de-DE", gender: .female, type: .standard),
        TTSVoice(id: "de-DE-WaveNet-A", name: "de-DE-WaveNet-A", languageCode: "de-DE", gender: .female, type: .wavenet),
        TTSVoice(id: "de-DE-WaveNet-B", name: "de-DE-WaveNet-B", languageCode: "de-DE", gender: .male, type: .wavenet),
        TTSVoice(id: "de-DE-WaveNet-C", name: "de-DE-WaveNet-C", languageCode: "de-DE", gender: .female, type: .wavenet),
        TTSVoice(id: "de-DE-Neural2-B", name: "de-DE-Neural2-B", languageCode: "de-DE", gender: .male, type: .neural2),
        TTSVoice(id: "de-DE-Neural2-C", name: "de-DE-Neural2-C", languageCode: "de-DE", gender: .female, type: .neural2),
    ]
    
    static let italianVoices: [TTSVoice] = [
        TTSVoice(id: "it-IT-Standard-A", name: "it-IT-Standard-A", languageCode: "it-IT", gender: .female, type: .standard),
        TTSVoice(id: "it-IT-Standard-B", name: "it-IT-Standard-B", languageCode: "it-IT", gender: .female, type: .standard),
        TTSVoice(id: "it-IT-Standard-C", name: "it-IT-Standard-C", languageCode: "it-IT", gender: .male, type: .standard),
        TTSVoice(id: "it-IT-WaveNet-A", name: "it-IT-WaveNet-A", languageCode: "it-IT", gender: .female, type: .wavenet),
        TTSVoice(id: "it-IT-WaveNet-B", name: "it-IT-WaveNet-B", languageCode: "it-IT", gender: .female, type: .wavenet),
        TTSVoice(id: "it-IT-WaveNet-C", name: "it-IT-WaveNet-C", languageCode: "it-IT", gender: .male, type: .wavenet),
        TTSVoice(id: "it-IT-Neural2-A", name: "it-IT-Neural2-A", languageCode: "it-IT", gender: .female, type: .neural2),
        TTSVoice(id: "it-IT-Neural2-C", name: "it-IT-Neural2-C", languageCode: "it-IT", gender: .male, type: .neural2),
    ]
    
    static let portugueseVoices: [TTSVoice] = [
        TTSVoice(id: "pt-BR-Standard-A", name: "pt-BR-Standard-A", languageCode: "pt-BR", gender: .female, type: .standard),
        TTSVoice(id: "pt-BR-Standard-B", name: "pt-BR-Standard-B", languageCode: "pt-BR", gender: .male, type: .standard),
        TTSVoice(id: "pt-BR-Standard-C", name: "pt-BR-Standard-C", languageCode: "pt-BR", gender: .female, type: .standard),
        TTSVoice(id: "pt-BR-WaveNet-A", name: "pt-BR-WaveNet-A", languageCode: "pt-BR", gender: .female, type: .wavenet),
        TTSVoice(id: "pt-BR-WaveNet-B", name: "pt-BR-WaveNet-B", languageCode: "pt-BR", gender: .male, type: .wavenet),
        TTSVoice(id: "pt-BR-WaveNet-C", name: "pt-BR-WaveNet-C", languageCode: "pt-BR", gender: .female, type: .wavenet),
        TTSVoice(id: "pt-BR-Neural2-A", name: "pt-BR-Neural2-A", languageCode: "pt-BR", gender: .female, type: .neural2),
        TTSVoice(id: "pt-BR-Neural2-B", name: "pt-BR-Neural2-B", languageCode: "pt-BR", gender: .male, type: .neural2),
    ]
    
    static func getVoices(for languageCode: String) -> [TTSVoice] {
        switch languageCode {
        case "es-ES": return spanishVoices
        case "es-US": return spanishLatinVoices
        case "en-US": return englishVoices
        case "fr-FR": return frenchVoices
        case "de-DE": return germanVoices
        case "it-IT": return italianVoices
        case "pt-BR": return portugueseVoices
        default: return []
        }
    }
}

extension TTSVoice {
    static func fromAPI(name: String, languageCode: String, ssmlGender: String?) -> TTSVoice {
        let gender = VoiceGender(rawValue: ssmlGender ?? "NEUTRAL") ?? .neutral
        let type: VoiceType
        if name.contains("WaveNet") {
            type = .wavenet
        } else if name.contains("Neural2") {
            type = .neural2
        } else if name.contains("Studio") {
            type = .studio
        } else if name.contains("Journey") {
            type = .journey
        } else if name.contains("News") {
            type = .news
        } else {
            type = .standard
        }
        return TTSVoice(id: name, name: name, languageCode: languageCode, gender: gender, type: type, isFavorite: false)
    }
}

