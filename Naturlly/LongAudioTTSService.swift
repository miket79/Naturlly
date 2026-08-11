//
//  LongAudioTTSService.swift
//  Naturlly TTS
//
//  Client stub for backend-mediated long audio synthesis (Google TTS v1beta1 synthesizeLongAudio)
//  This service talks to your backend, which holds secure credentials and writes to GCS.
//

import Foundation

struct LongAudioStartRequest: Codable {
    let text: String
    let languageCode: String
    let voiceName: String?
    let speakingRate: Double
    let pitch: Double
    let outputFileName: String // filename in mounted GCS bucket
}

struct LongAudioStartResponse: Codable {
    let operationId: String
    let expectedFile: String?
}

struct LongAudioStatusResponse: Codable {
    let done: Bool
    let error: String?
    let downloadUrl: String? // relative URL like /tts/long/download/filename.wav
}

final class LongAudioTTSService {
    // Configure these endpoints to match your backend routes
    private let baseURL: URL
    private let urlSession: URLSession

    init(baseURL: URL, urlSession: URLSession = .shared) {
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    // POST /tts/long/start
    func startSynthesis(
        text: String,
        languageCode: String,
        voiceName: String?,
        speakingRate: Double,
        pitch: Double,
        outputFileName: String
    ) async throws -> String { // returns operationId
        let req = LongAudioStartRequest(
            text: text,
            languageCode: languageCode,
            voiceName: voiceName,
            speakingRate: speakingRate,
            pitch: pitch,
            outputFileName: outputFileName
        )
        let url = baseURL.appending(path: "/tts/long/start")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(req)

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "LongAudioTTSService", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        let decoded = try JSONDecoder().decode(LongAudioStartResponse.self, from: data)
        return decoded.operationId
    }

    // GET /tts/long/status?operationId=...
    func getStatus(operationId: String) async throws -> LongAudioStatusResponse {
        var comps = URLComponents(url: baseURL.appending(path: "/tts/long/status"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "operationId", value: operationId)]
        let url = comps.url!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "LongAudioTTSService", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        return try JSONDecoder().decode(LongAudioStatusResponse.self, from: data)
    }

    // GET /tts/long/download/:fileName
    // Returns binary audio data (WAV) from backend (served from mounted GCS bucket)
    func downloadOutput(fileName: String) async throws -> Data {
        let url = baseURL.appending(path: "/tts/long/download/\(fileName)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "LongAudioTTSService", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        return data
    }
}
