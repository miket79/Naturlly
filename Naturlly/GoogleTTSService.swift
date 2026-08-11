//
//  GoogleTTSService.swift
//  Naturlly TTS
//
//  Google Cloud Text-to-Speech (v1) client
//

import Foundation
import AVFoundation
import os

class GoogleTTSService {
    // Cloud Text-to-Speech endpoint
    private let endpoint = "https://texttospeech.googleapis.com/v1/text:synthesize"
    private let apiKey: String
    private let maxBytesPerRequest = 4500 // límite de seguridad para TTS clásico (UTF-8 bytes)
    var useSSMLPauses: Bool = false // Gemini TTS no requiere SSML en esta integración
    
    private func buildSSML(from text: String) -> String {
        // Limpieza básica para SSML
        var ssml = text
        // Escapar caracteres especiales mínimos
        ssml = ssml.replacingOccurrences(of: "&", with: "&amp;")
                   .replacingOccurrences(of: "<", with: "&lt;")
                   .replacingOccurrences(of: ">", with: "&gt;")

        // Pausas cortas en comas y medias en puntos
        // Nota: Evitamos duplicar signos; trabajamos sobre espacios
        ssml = ssml.replacingOccurrences(of: ", ", with: ", <break time=\"200ms\"/> ")
        ssml = ssml.replacingOccurrences(of: ". ", with: ". <break time=\"400ms\"/> ")
        ssml = ssml.replacingOccurrences(of: "? ", with: "? <break time=\"400ms\"/> ")
        ssml = ssml.replacingOccurrences(of: "! ", with: "! <break time=\"400ms\"/> ")

        return "<speak>\n\(ssml)\n</speak>"
    }
    
    init(apiKey: String, useVertex: Bool = false) {
        self.apiKey = apiKey
    }
    
    func synthesizeSpeech(
        text: String,
        language: TTSLanguage,
        speakingRate: Double = 1.0,
        pitch: Double = 0.0,
        voice: TTSVoice? = nil
    ) async throws -> Data {
        guard !text.isEmpty else { throw TTSError.emptyText }
        guard !apiKey.isEmpty else { throw TTSError.missingAPIKey }
        
        let textData = Data(text.utf8)
        let limit = TextChunker.effectiveMaxBytes(base: TextChunker.maxBytes, marginPercent: useSSMLPauses ? 10 : 0, overheadBytes: useSSMLPauses ? 200 : 0)
        if textData.count <= limit {
            return try await synthesizeSingleRequest(
                text: text,
                language: language,
                speakingRate: speakingRate,
                pitch: pitch,
                voice: voice
            )
        }
        
        return try await synthesizeLongText(
            text: text,
            language: language,
            speakingRate: speakingRate,
            pitch: pitch,
            voice: voice
        )
    }

    
    
    // MARK: - Single Request (for short texts)
    private func synthesizeSingleRequest(
        text: String,
        language: TTSLanguage,
        speakingRate: Double,
        pitch: Double,
        voice: TTSVoice?
    ) async throws -> Data {
        guard var urlComponents = URLComponents(string: endpoint) else {
            throw TTSError.invalidURL
        }
        urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = urlComponents.url else {
            throw TTSError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Use provided voice name (e.g., gemini-1.5-pro-001-tts) or fallback to language default
        let voiceSelection = ClassicTTSRequest.VoiceSelectionParams(
            languageCode: voice?.languageCode ?? language.code,
            name: voice?.name ?? language.voiceName
        )
        let audioConfig = ClassicTTSRequest.AudioConfig(
            audioEncoding: "MP3",
            speakingRate: speakingRate,
            pitch: pitch
        )

        let input: ClassicTTSRequest.Input
        if useSSMLPauses {
            input = .init(ssml: buildSSML(from: text))
        } else {
            input = .init(text: text)
        }
        let body = ClassicTTSRequest(
            input: input,
            voice: voiceSelection,
            audioConfig: audioConfig
        )
        urlRequest.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TTSError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            switch httpResponse.statusCode {
            case 401, 403: throw TTSError.forbidden
            case 429: throw TTSError.quotaExceeded
            case 400: throw TTSError.badRequest(message: errorMessage)
            default: throw TTSError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
            }
        }

        let decoder = JSONDecoder()
        let ttsResponse = try decoder.decode(ClassicTTSResponse.self, from: data)
        guard let audioContent = ttsResponse.audioContent, let audioData = Data(base64Encoded: audioContent) else {
            throw TTSError.invalidAudioData
        }
        return audioData
    }
    
    // MARK: - Long Text Processing
    private func synthesizeLongText(
        text: String,
        language: TTSLanguage,
        speakingRate: Double,
        pitch: Double,
        voice: TTSVoice?
    ) async throws -> Data {
        
        // Split text into chunks
        let chunks = TextChunker.split(text, maxBytes: TextChunker.maxBytes, marginPercent: useSSMLPauses ? 10 : 0, overheadBytes: useSSMLPauses ? 200 : 0)
        
        guard !chunks.isEmpty else {
            throw TTSError.emptyText
        }
        
        // Process each chunk
        var audioChunks: [Data] = []
        
        for (index, chunk) in chunks.enumerated() {
            print("Procesando fragmento \(index + 1) de \(chunks.count)...")
            
            let audioData = try await synthesizeSingleRequest(
                text: chunk,
                language: language,
                speakingRate: speakingRate,
                pitch: pitch,
                voice: voice
            )
            
            audioChunks.append(audioData)
            
            // Small delay to avoid rate limiting
            if index < chunks.count - 1 {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        }
        
        // Merge audio chunks
        return mergeMP3Data(chunks: audioChunks)
    }
    
    // MARK: - Audio Merging
    private func mergeMP3Data(chunks: [Data]) -> Data {
        // Simple concatenation works for MP3 files
        var mergedData = Data()
        
        for chunk in chunks {
            mergedData.append(chunk)
        }
        
        return mergedData
    }
}

// Classic Cloud TTS models
private struct ClassicTTSRequest: Codable {
    let input: Input
    let voice: VoiceSelectionParams
    let audioConfig: AudioConfig
    
    struct Input: Codable {
        let text: String?
        let ssml: String?
        init(text: String) { self.text = text; self.ssml = nil }
        init(ssml: String) { self.text = nil; self.ssml = ssml }
    }
    
    struct VoiceSelectionParams: Codable {
        let languageCode: String
        let name: String?
    }
    
    struct AudioConfig: Codable {
        let audioEncoding: String
        let speakingRate: Double
        let pitch: Double
    }
}

private struct ClassicTTSResponse: Codable {
    let audioContent: String?
}

enum TTSError: LocalizedError {
    case emptyText
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case invalidAudioData
    case forbidden
    case quotaExceeded
    case badRequest(message: String)
    case apiError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "El texto no puede estar vacío"
        case .missingAPIKey:
            return "La clave API no está configurada"
        case .invalidURL:
            return "URL inválida"
        case .invalidResponse:
            return "Respuesta inválida del servidor"
        case .invalidAudioData:
            return "No se pudo decodificar el audio"
        case .forbidden:
            return """
            Error 403: Acceso denegado
            
            Posibles causas:
            • API Key inválida o sin permisos para Generative Language API
            • Restricciones de clave (IP, app bundle) impiden la llamada
            
            Revisa la consola de Google Cloud: habilita "Generative Language API"
            y verifica que la clave no tenga restricciones que bloqueen la app.
            """
        case .quotaExceeded:
            return """
            Error 429: Cuota Excedida
            
            Se alcanzó el límite de peticiones/cuota. Intenta más tarde o revisa
            los límites de uso del proyecto en Google Cloud.
            """
        case .badRequest(let message):
            return "Solicitud inválida: \(message)"
        case .apiError(let statusCode, let message):
            return "Error API (\(statusCode)): \(message)"
        }
    }
}


