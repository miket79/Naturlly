import Foundation
import os

// Gemini TTS client using Generative Language API v1beta batchGenerateContent
// Model: gemini-2.5-pro-preview-tts
// Endpoint: https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro-preview-tts:batchGenerateContent?key=API_KEY

final class GeminiTTSService {
    private let apiKey: String
    private let model: String = "gemini-1.5-pro-001-tts"
    private let endpointBase: String = "https://generativelanguage.googleapis.com/v1beta/models/"
    private let audioEncoding: String = "MP3"
    private let maxBytesPerRequest = 4500 // keep parity with classic service safety margin
    private let logger = Logger(subsystem: "com.naturlly.tts", category: "gemini")

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func synthesizeSpeech(
        text: String,
        language: TTSLanguage,
        speakingRate: Double = 1.0,
        pitch: Double = 0.0,
        voice: TTSVoice? = nil
    ) async throws -> Data {
        logger.log("[Gemini] synthesizeSpeech start | model=\(self.model, privacy: .public) textBytes=\(text.utf8.count) rate=\(speakingRate) pitch=\(pitch)")
        guard !text.isEmpty else { throw TTSError.emptyText }
        guard !apiKey.isEmpty else { throw TTSError.missingAPIKey }

        // If text larger than safe limit, split and concat like classic service
        if text.utf8.count > TextChunker.maxBytes {
            let chunks = TextChunker.split(text, maxBytes: TextChunker.maxBytes)
            var all = Data()
            for (idx, chunk) in chunks.enumerated() {
                let part = try await synthesizeSingle(text: chunk, language: language, speakingRate: speakingRate, pitch: pitch, voice: voice)
                all.append(part)
                logger.log("[Gemini] chunk \(idx+1)/\(chunks.count) appended | bytes=\(part.count)")
                if idx < chunks.count - 1 { try await Task.sleep(nanoseconds: 300_000_000) }
            }
            return all
        } else {
            return try await synthesizeSingle(text: text, language: language, speakingRate: speakingRate, pitch: pitch, voice: voice)
        }
    }

    // MARK: - Single request via batchGenerateContent (single item in requests)
    private func synthesizeSingle(
        text: String,
        language: TTSLanguage,
        speakingRate: Double,
        pitch: Double,
        voice: TTSVoice?
    ) async throws -> Data {
        let start = Date()
        guard var components = URLComponents(string: endpointBase + model + ":batchGenerateContent") else {
            throw TTSError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        let safeURL = (components.url?.absoluteString.replacingOccurrences(of: apiKey, with: "***")) ?? "<nil>"
        logger.log("[Gemini] POST \(safeURL, privacy: .public)")
        guard let url = components.url else { throw TTSError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build audioConfig dictionary (will be nested as voice)
        var voiceDict: [String: Any] = [
            "languageCode": language.code
        ]
        if let v = voice, v.type != .studio {
            voiceDict["name"] = v.name
        }

        let outputAudioConfig: [String: Any] = [
            "audioEncoding": audioEncoding,
            "speakingRate": speakingRate,
            "pitch": pitch,
            "voice": voiceDict
        ]

        let generationConfig: [String: Any] = [
            "temperature": 0.0
        ]

        let payload: [String: Any] = [
            "requests": [
                [
                    "contents": [
                        [
                            "role": "user",
                            "parts": [["text": text]]
                        ]
                    ],
                    "generationConfig": generationConfig,
                    "responseMimeType": "audio/mpeg",
                    "outputAudioConfig": outputAudioConfig
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        logger.log("[Gemini] payload bytes=\(request.httpBody?.count ?? 0)")

        let (data, response) = try await URLSession.shared.data(for: request)
        let elapsed = Date().timeIntervalSince(start)
        logger.log("[Gemini] response status=\(((response as? HTTPURLResponse)?.statusCode ?? -1)) time=\(elapsed, format: .fixed(precision: 3))s bytes=\(data.count)")

        guard let http = response as? HTTPURLResponse else { throw TTSError.invalidResponse }
        guard http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            let preview = String(data: data.prefix(512), encoding: .utf8) ?? "<non-utf8>"
            logger.error("[Gemini] HTTP \(http.statusCode) error: \(preview, privacy: .public)")
            switch http.statusCode {
            case 401, 403: throw TTSError.forbidden
            case 429: throw TTSError.quotaExceeded
            case 400: throw TTSError.badRequest(message: msg)
            default: throw TTSError.apiError(statusCode: http.statusCode, message: msg)
            }
        }

        // Parse response. For batchGenerateContent, typical shape:
        // {
        //   "responses": [
        //     {
        //       "candidates": [
        //         {
        //           "content": { "parts": [ { "inlineData": { "mimeType": "audio/mpeg", "data": "base64..." } } ] }
        //         }
        //       ]
        //     }
        //   ]
        // }
        // Note: The exact schema can vary; we support the inlineData path here and can extend if needed.
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let responses = json?["responses"] as? [[String: Any]], let first = responses.first else {
            throw TTSError.invalidResponse
        }
        guard let candidates = first["candidates"] as? [[String: Any]], let cand = candidates.first else {
            throw TTSError.invalidResponse
        }
        guard let content = cand["content"] as? [String: Any], let parts = content["parts"] as? [[String: Any]] else {
            throw TTSError.invalidResponse
        }

        // Find first inlineData with audio
        for part in parts {
            if let inline = part["inlineData"] as? [String: Any], let b64 = inline["data"] as? String {
                if let audio = Data(base64Encoded: b64) {
                    logger.log("[Gemini] decoded audio bytes=\(audio.count)")
                    return audio
                }
            }
            // Some variants may return {"audioData":"..."}
            if let b64 = part["audioData"] as? String, let audio = Data(base64Encoded: b64) {
                logger.log("[Gemini] decoded audio bytes=\(audio.count)")
                return audio
            }
        }

        // If not found, attempt alternative top-level path (future-proofing)
        if let b64 = (json?["audioData"] as? String), let audio = Data(base64Encoded: b64) {
            logger.log("[Gemini] decoded audio bytes=\(audio.count)")
            return audio
        }

        throw TTSError.invalidAudioData
    }
}

