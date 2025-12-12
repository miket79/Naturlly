//
//  GoogleTTSService.swift
//  Naturlly TTS
//
//  Service to interact with Google Cloud Text-to-Speech API
//

import Foundation
import AVFoundation

class GoogleTTSService {
    private let apiKey: String
    private let useVertex: Bool
    private let maxBytesPerRequest = 4500 // Límite de 5000, usamos 4500 para margen
    var useSSMLPauses: Bool = true // Habilitar pausas automáticas en comas y puntos
    
    private var synthesizeURLString: String {
        useVertex ? "https://texttospeech.googleapis.com/v1beta1/text:synthesize" : "https://texttospeech.googleapis.com/v1/text:synthesize"
    }
    
    init(apiKey: String, useVertex: Bool = false) {
        self.apiKey = apiKey
        self.useVertex = useVertex
    }
    
    func synthesizeSpeech(
        text: String,
        language: TTSLanguage,
        speakingRate: Double = 1.0,
        pitch: Double = 0.0,
        voice: TTSVoice? = nil
    ) async throws -> Data {
        
        guard !text.isEmpty else {
            throw TTSError.emptyText
        }
        
        guard !apiKey.isEmpty else {
            throw TTSError.missingAPIKey
        }
        
        // Check text size
        let textData = Data(text.utf8)
        
        // If text is within limit, process normally
        if textData.count <= maxBytesPerRequest {
            return try await synthesizeSingleRequest(
                text: text,
                language: language,
                speakingRate: speakingRate,
                pitch: pitch,
                voice: voice
            )
        }
        
        // Text is too long, split and merge
        return try await synthesizeLongText(
            text: text,
            language: language,
            speakingRate: speakingRate,
            pitch: pitch,
            voice: voice
        )
    }

    
    
    // MARK: - SSML Processing
    private func addSSMLPauses(_ text: String) -> String {
        guard useSSMLPauses else { return text }
        
        var processedText = text
        
        // Agregar pausas solo cuando los signos están seguidos de espacio o fin de línea
        // Esto evita pausas en números decimales, URLs, etc.
        
        // Comas seguidas de espacio (300ms)
        processedText = processedText.replacingOccurrences(
            of: ", ",
            with: ",<break time=\"300ms\"/> "
        )
        
        // Puntos seguidos de espacio o fin de línea (500ms)
        // Primero puntos con espacio
        processedText = processedText.replacingOccurrences(
            of: ". ",
            with: ".<break time=\"500ms\"/> "
        )
        // Luego puntos al final de línea
        processedText = processedText.replacingOccurrences(
            of: ".\n",
            with: ".<break time=\"500ms\"/>\n"
        )
        
        // Punto y coma con espacio (400ms)
        processedText = processedText.replacingOccurrences(
            of: "; ",
            with: ";<break time=\"400ms\"/> "
        )
        
        // Dos puntos con espacio (350ms)
        processedText = processedText.replacingOccurrences(
            of: ": ",
            with: ":<break time=\"350ms\"/> "
        )
        
        // Interrogación con espacio o fin de línea (500ms)
        processedText = processedText.replacingOccurrences(
            of: "? ",
            with: "?<break time=\"500ms\"/> "
        )
        processedText = processedText.replacingOccurrences(
            of: "?\n",
            with: "?<break time=\"500ms\"/>\n"
        )
        
        // Exclamación con espacio o fin de línea (500ms)
        processedText = processedText.replacingOccurrences(
            of: "! ",
            with: "!<break time=\"500ms\"/> "
        )
        processedText = processedText.replacingOccurrences(
            of: "!\n",
            with: "!<break time=\"500ms\"/>\n"
        )
        
        // Envolver en SSML
        return "<speak>\(processedText)</speak>"
    }


    // MARK: - Single Request (for short texts)
    private func synthesizeSingleRequest(
        text: String,
        language: TTSLanguage,
        speakingRate: Double,
        pitch: Double,
        voice: TTSVoice?
    ) async throws -> Data {
        
        // Determine which voice to use
        let selectedVoice = voice ?? TTSVoice.getVoices(for: language.code).first ?? TTSVoice(
            id: language.voiceName,
            name: language.voiceName,
            languageCode: language.code,
            gender: .female,
            type: .standard
        )
        
        // Procesar texto con SSML si está habilitado
        let processedText = useSSMLPauses ? addSSMLPauses(text) : text
        
        // Construct request
        let request = TTSRequest(
            input: useSSMLPauses ? TTSRequest.TextInput(ssml: processedText) : TTSRequest.TextInput(text: text),
            voice: TTSRequest.VoiceSelection(
                languageCode: selectedVoice.languageCode,
                name: selectedVoice.name
            ),
            audioConfig: TTSRequest.AudioConfig(
                audioEncoding: "MP3",
                speakingRate: speakingRate,
                pitch: pitch
            )
        )
        
        // Create URL with API key
        guard var urlComponents = URLComponents(string: synthesizeURLString) else {
            throw TTSError.invalidURL
        }
        urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        
        guard let url = urlComponents.url else {
            throw TTSError.invalidURL
        }
        
        // Configure HTTP request
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Encode request body
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        // Execute request
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TTSError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            
            // Enhanced error messages for common issues
            if httpResponse.statusCode == 403 {
                throw TTSError.forbidden
            } else if httpResponse.statusCode == 429 {
                throw TTSError.quotaExceeded
            } else if httpResponse.statusCode == 400 {
                throw TTSError.badRequest(message: errorMessage)
            } else {
                throw TTSError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
            }
        }
        
        // Decode response
        let decoder = JSONDecoder()
        let ttsResponse = try decoder.decode(TTSResponse.self, from: data)
        
        // Decode base64 audio content
        guard let audioData = Data(base64Encoded: ttsResponse.audioContent) else {
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
        let chunks = splitTextIntoChunks(text: text, maxBytes: maxBytesPerRequest)
        
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
        return try mergeMP3Data(chunks: audioChunks)
    }
    
    // MARK: - Text Splitting
    private func splitTextIntoChunks(text: String, maxBytes: Int) -> [String] {
        var chunks: [String] = []
        var currentChunk = ""
        
        // Split by sentences first (by period, exclamation, question mark)
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: "!?¿¡"))
        
        for sentence in sentences {
            let trimmedSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedSentence.isEmpty {
                continue
            }
            
            // Add punctuation back
            let sentenceWithPunctuation = trimmedSentence + "."
            
            // Check if adding this sentence would exceed the limit
            let testChunk = currentChunk.isEmpty ? sentenceWithPunctuation : currentChunk + " " + sentenceWithPunctuation
            let testData = Data(testChunk.utf8)
            
            if testData.count > maxBytes {
                // Current chunk is full, save it
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk)
                }
                
                // Check if single sentence is too long
                let sentenceData = Data(sentenceWithPunctuation.utf8)
                if sentenceData.count > maxBytes {
                    // Split long sentence by words
                    let subChunks = splitLongSentence(sentence: sentenceWithPunctuation, maxBytes: maxBytes)
                    chunks.append(contentsOf: subChunks)
                    currentChunk = ""
                } else {
                    currentChunk = sentenceWithPunctuation
                }
            } else {
                // Add sentence to current chunk
                if currentChunk.isEmpty {
                    currentChunk = sentenceWithPunctuation
                } else {
                    currentChunk += " " + sentenceWithPunctuation
                }
            }
        }
        
        // Add remaining chunk
        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }
        
        return chunks
    }
    
    private func splitLongSentence(sentence: String, maxBytes: Int) -> [String] {
        var chunks: [String] = []
        let words = sentence.split(separator: " ")
        var currentChunk = ""
        
        for word in words {
            let testChunk = currentChunk.isEmpty ? String(word) : currentChunk + " " + String(word)
            let testData = Data(testChunk.utf8)
            
            if testData.count > maxBytes {
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk)
                }
                currentChunk = String(word)
            } else {
                currentChunk = testChunk
            }
        }
        
        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }
        
        return chunks
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
            return "La clave API de Google no está configurada"
        case .invalidURL:
            return "URL inválida"
        case .invalidResponse:
            return "Respuesta inválida del servidor"
        case .invalidAudioData:
            return "No se pudo decodificar el audio"
        case .forbidden:
            return """
            Error 403: Acceso Denegado
            
            Posibles causas:
            • La API Key no es válida
            • La API de Text-to-Speech no está habilitada
            • La API Key tiene restricciones que bloquean esta app
            
            Solución:
            1. Ve a console.cloud.google.com
            2. Verifica que "Cloud Text-to-Speech API" esté habilitada
            3. En "Credentials", verifica tu API Key
            4. Si tiene restricciones, agrégala o crea una nueva sin restricciones
            """
        case .quotaExceeded:
            return """
            Error 429: Cuota Excedida
            
            Has superado el límite gratuito de 4 millones de caracteres/mes.
            Espera unos minutos o revisa tu cuota en Google Cloud Console.
            """
        case .badRequest(let message):
            return "Solicitud inválida: \(message)"
        case .apiError(let statusCode, let message):
            return "Error API (\(statusCode)): \(message)"
        }
    }
}

