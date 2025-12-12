//
//  TTSLanguage.swift
//  Naturlly TTS
//
//  Language model for Text-to-Speech
//

import Foundation

struct TTSLanguage: Identifiable, Hashable {
    let id: String
    let name: String
    let code: String
    let voiceName: String
    
    static let availableLanguages: [TTSLanguage] = [
        TTSLanguage(id: "es", name: "Español", code: "es-ES", voiceName: "es-ES-Standard-A"),
        TTSLanguage(id: "en", name: "English", code: "en-US", voiceName: "en-US-Standard-C"),
        TTSLanguage(id: "es-US", name: "Español (Latino)", code: "es-US", voiceName: "es-US-Standard-A"),
        TTSLanguage(id: "fr", name: "Français", code: "fr-FR", voiceName: "fr-FR-Standard-A"),
        TTSLanguage(id: "de", name: "Deutsch", code: "de-DE", voiceName: "de-DE-Standard-A"),
        TTSLanguage(id: "it", name: "Italiano", code: "it-IT", voiceName: "it-IT-Standard-A"),
        TTSLanguage(id: "pt", name: "Português", code: "pt-BR", voiceName: "pt-BR-Standard-A"),
    ]
}
