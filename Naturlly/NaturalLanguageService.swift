//
//  NaturalLanguageService.swift
//  Naturlly TTS
//
//  Google Cloud Natural Language API integration
//

import Foundation

enum NaturalLanguageError: Error, LocalizedError {
    case missingAPIKey
    case networkError(String)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Falta la API Key de Google Cloud"
        case .networkError(let message):
            return "Error de red: \(message)"
        case .invalidResponse:
            return "Respuesta inválida de la API"
        }
    }
}

struct TextAnalysis {
    let sentiment: SentimentScore
    let entities: [Entity]
    let sentences: [Sentence]
    let language: String
    
    struct SentimentScore {
        let score: Double // -1.0 (negativo) a 1.0 (positivo)
        let magnitude: Double // 0.0 a infinito, intensidad emocional
    }
    
    struct Entity {
        let name: String
        let type: String // PERSON, LOCATION, ORGANIZATION, etc.
        let salience: Double // 0.0 a 1.0, importancia
        let mentions: [Mention]
        
        struct Mention {
            let text: String
            let type: String // PROPER, COMMON
        }
    }
    
    struct Sentence {
        let text: String
        let sentiment: SentimentScore
        let beginOffset: Int
    }
}

class NaturalLanguageService {
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // Analizar texto completo con todas las características
    func analyzeText(_ text: String) async throws -> TextAnalysis {
        let url = URL(string: "https://language.googleapis.com/v1/documents:annotateText?key=\(apiKey)")!
        
        let requestBody: [String: Any] = [
            "document": [
                "type": "PLAIN_TEXT",
                "content": text
            ],
            "features": [
                "extractSyntax": true,
                "extractEntities": true,
                "extractDocumentSentiment": true,
                "extractEntitySentiment": false,
                "classifyText": false
            ],
            "encodingType": "UTF8"
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NaturalLanguageError.networkError("Respuesta inválida")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Error desconocido"
            throw NaturalLanguageError.networkError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
        
        return try parseAnalysisResponse(data)
    }
    
    // Obtener sugerencias de pausa y énfasis basadas en el análisis
    func getSSMLEnhancements(from analysis: TextAnalysis) -> String {
        var enhancements: [String] = []
        
        // Ajustar velocidad según sentimiento
        if analysis.sentiment.magnitude > 0.5 {
            if analysis.sentiment.score > 0.3 {
                enhancements.append("Tono positivo detectado - considerar voz más animada")
            } else if analysis.sentiment.score < -0.3 {
                enhancements.append("Tono negativo detectado - considerar voz más seria")
            }
        }
        
        // Resaltar entidades importantes
        let importantEntities = analysis.entities.filter { $0.salience > 0.1 }
        if !importantEntities.isEmpty {
            enhancements.append("Entidades importantes detectadas: \(importantEntities.map { $0.name }.joined(separator: ","))")
        }
        
        return enhancements.joined(separator: "\n")
    }
    
    // Obtener ajustes de velocidad y tono basados en sentimiento
    func getSpeechParameters(from analysis: TextAnalysis) -> (rate: Double, pitch: Double) {
        var rate = 1.0
        var pitch = 0.0
        
        // Ajustar velocidad según magnitud emocional
        if analysis.sentiment.magnitude > 0.7 {
            rate = 1.1 // Más rápido para contenido emocional
        } else if analysis.sentiment.magnitude < 0.3 {
            rate = 0.95 // Más lento para contenido neutral/técnico
        }
        
        // Ajustar tono según sentimiento
        if analysis.sentiment.score > 0.5 {
            pitch = 2.0 // Tono más alto para contenido positivo
        } else if analysis.sentiment.score < -0.5 {
            pitch = -2.0 // Tono más bajo para contenido negativo
        }
        
        return (rate, pitch)
    }
    
    // Dividir texto en oraciones con análisis de sentimiento
    func getSentencesWithSentiment(_ text: String) async throws -> [TextAnalysis.Sentence] {
        let analysis = try await analyzeText(text)
        return analysis.sentences
    }
    
    private func parseAnalysisResponse(_ data: Data) throws -> TextAnalysis {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NaturalLanguageError.invalidResponse
        }
        
        // Parse sentiment
        var sentiment = TextAnalysis.SentimentScore(score: 0, magnitude: 0)
        if let sentimentData = json["documentSentiment"] as? [String: Any] {
            sentiment = TextAnalysis.SentimentScore(
                score: sentimentData["score"] as? Double ?? 0,
                magnitude: sentimentData["magnitude"] as? Double ?? 0
            )
        }
        
        // Parse entities
        var entities: [TextAnalysis.Entity] = []
        if let entitiesData = json["entities"] as? [[String: Any]] {
            entities = entitiesData.compactMap { entityDict in
                guard let name = entityDict["name"] as? String,
                      let type = entityDict["type"] as? String else { return nil }
                
                let salience = entityDict["salience"] as? Double ?? 0
                
                var mentions: [TextAnalysis.Entity.Mention] = []
                if let mentionsData = entityDict["mentions"] as? [[String: Any]] {
                    mentions = mentionsData.compactMap { mentionDict in
                        guard let textData = mentionDict["text"] as? [String: Any],
                              let content = textData["content"] as? String,
                              let type = mentionDict["type"] as? String else { return nil }
                        return TextAnalysis.Entity.Mention(text: content, type: type)
                    }
                }
                
                return TextAnalysis.Entity(name: name, type: type, salience: salience, mentions: mentions)
            }
        }
        
        // Parse sentences
        var sentences: [TextAnalysis.Sentence] = []
        if let sentencesData = json["sentences"] as? [[String: Any]] {
            sentences = sentencesData.compactMap { sentenceDict in
                guard let textData = sentenceDict["text"] as? [String: Any],
                      let content = textData["content"] as? String else { return nil }
                
                let beginOffset = textData["beginOffset"] as? Int ?? 0
                
                var sentimentScore = TextAnalysis.SentimentScore(score: 0, magnitude: 0)
                if let sentData = sentenceDict["sentiment"] as? [String: Any] {
                    sentimentScore = TextAnalysis.SentimentScore(
                        score: sentData["score"] as? Double ?? 0,
                        magnitude: sentData["magnitude"] as? Double ?? 0
                    )
                }
                
                return TextAnalysis.Sentence(text: content, sentiment: sentimentScore, beginOffset: beginOffset)
            }
        }
        
        // Detect language
        let language = json["language"] as? String ?? "es"
        
        return TextAnalysis(
            sentiment: sentiment,
            entities: entities,
            sentences: sentences,
            language: language
        )
    }
}
