import Foundation

private struct VoicesListResponse: Decodable {
    let voices: [VoiceItem]?
    struct VoiceItem: Decodable {
        let name: String
        let languageCodes: [String]
        let ssmlGender: String?
        let naturalSampleRateHertz: Int?
    }
}

final class VoiceService {
    static let shared = VoiceService()
    private init() {}
    
    private var cache: [String: [TTSVoice]] = [:] // key: provider+language
    
    func fetchVoices(apiKey: String, languageCode: String?, useVertex: Bool) async throws -> [TTSVoice] {
        guard !apiKey.isEmpty else {
            throw TTSError.missingAPIKey
        }
        // Build URL
        var components = URLComponents(string: useVertex ? "https://texttospeech.googleapis.com/v1beta1/voices" : "https://texttospeech.googleapis.com/v1/voices")!
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "key", value: apiKey)]
        if let languageCode = languageCode, !languageCode.isEmpty {
            queryItems.append(URLQueryItem(name: "languageCode", value: languageCode))
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            throw TTSError.invalidURL
        }
        
        let cacheKey = "\(useVertex ? "vertex" : "google")_\(languageCode ?? "all")"
        if let cached = cache[cacheKey] {
            return cached
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TTSError.apiError(statusCode: status, message: message)
        }
        
        let decoder = JSONDecoder()
        let list = try decoder.decode(VoicesListResponse.self, from: data)
        var results: [TTSVoice] = []
        
        for item in list.voices ?? [] {
            let gender = VoiceGender(rawValue: item.ssmlGender ?? "NEUTRAL") ?? .neutral
            
            // Determine which language codes to include
            let codes = item.languageCodes
            let targetCodes: [String]
            if let languageCode = languageCode, !languageCode.isEmpty {
                if codes.contains(languageCode) {
                    targetCodes = [languageCode]
                } else {
                    continue
                }
            } else {
                targetCodes = codes
            }
            
            let type: VoiceType
            if item.name.contains("WaveNet") {
                type = .wavenet
            } else if item.name.contains("Neural2") {
                type = .neural2
            } else if item.name.contains("Studio") {
                type = .studio
            } else if item.name.contains("Journey") {
                type = .journey
            } else if item.name.contains("News") {
                type = .news
            } else {
                type = .standard
            }
            
            for lc in targetCodes {
                results.append(TTSVoice(id: item.name, name: item.name, languageCode: lc, gender: gender, type: type))
            }
        }
        
        results.sort { $0.name < $1.name }
        cache[cacheKey] = results
        return results
    }
}
