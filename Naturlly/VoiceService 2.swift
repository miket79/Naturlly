//
//  VoiceService.swift
//  Naturlly TTS
//
//  Servicio mínimo para obtener voces. Para MVP, intentamos la API clásica
//  de Google TTS (voices:list). Si falla, usamos las listas estáticas de TTSVoice.
//

import Foundation

final class LegacyVoiceService {
    static let shared = LegacyVoiceService()
    private init() {}

    enum ServiceError: LocalizedError {
        case missingAPIKey
        case invalidResponse
        case network(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: return "Falta API Key"
            case .invalidResponse: return "Respuesta inválida"
            case .network(let m): return "Error de red: \(m)"
            }
        }
    }

    // Nota: useVertex se ignora por ahora en MVP (TTS clásico)
    func fetchVoices(apiKey: String, languageCode: String, useVertex: Bool) async throws -> [TTSVoice] {
        guard !apiKey.isEmpty else {
            // Usa fallback local si no hay clave
            return localVoices(for: languageCode)
        }

        // Endpoint clásico de TTS para listar voces
        guard var comps = URLComponents(string: "https://texttospeech.googleapis.com/v1/voices") else {
            return localVoices(for: languageCode)
        }
        comps.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = comps.url else { return localVoices(for: languageCode) }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                return localVoices(for: languageCode)
            }
            if let voices = try parseVoicesResponse(data: data, filter: languageCode) {
                return voices
            } else {
                return localVoices(for: languageCode)
            }
        } catch {
            return localVoices(for: languageCode)
        }
    }

    private func parseVoicesResponse(data: Data, filter languageCode: String) throws -> [TTSVoice]? {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["voices"] as? [[String: Any]] else { return nil }

        let voices: [TTSVoice] = list.compactMap { item in
            guard let name = item["name"] as? String,
                  let languages = item["languageCodes"] as? [String],
                  let ssmlGender = item["ssmlGender"] as? String else { return nil }
            // Filtrar por idioma si aplica
            guard languageCode.isEmpty || languages.contains(languageCode) else { return nil }
            return TTSVoice.fromAPI(name: name, languageCode: languageCode, ssmlGender: ssmlGender)
        }
        return voices.isEmpty ? nil : voices
    }

    private func localVoices(for languageCode: String) -> [TTSVoice] {
        return TTSVoice.getVoices(for: languageCode)
    }
}
