//
//  TTSServiceManager.swift
//  Naturlly TTS
//
//  Manager to handle both regular TTS and Long Audio TTS services
//

import Foundation

enum TTSServiceType {
    case regular
    case longAudio
}

class TTSServiceManager {
    private let apiKey: String
    private let backendURL: URL
    private let gcsBucket: String
    private let serviceType: TTSServiceType
    
    // Regular TTS service
    private lazy var googleTTSService: GoogleTTSService = {
        GoogleTTSService(apiKey: apiKey)
    }()
    
    // Long Audio TTS service
    private lazy var longAudioService: LongAudioTTSService = {
        LongAudioTTSService(baseURL: backendURL)
    }()
    
    init(apiKey: String, backendURL: URL, gcsBucket: String, serviceType: TTSServiceType = .regular) {
        self.apiKey = apiKey
        self.backendURL = backendURL
        self.gcsBucket = gcsBucket
        self.serviceType = serviceType
    }
    
    func synthesizeSpeech(
        text: String,
        language: TTSLanguage,
        speakingRate: Double = 1.0,
        pitch: Double = 0.0,
        voice: TTSVoice? = nil,
        useSSMLPauses: Bool = true
    ) async throws -> Data {
        
        switch serviceType {
        case .regular:
            return try await synthesizeWithRegularService(
                text: text,
                language: language,
                speakingRate: speakingRate,
                pitch: pitch,
                voice: voice,
                useSSMLPauses: useSSMLPauses
            )
            
        case .longAudio:
            return try await synthesizeWithLongAudioService(
                text: text,
                language: language,
                speakingRate: speakingRate,
                pitch: pitch,
                voice: voice
            )
        }
    }
    
    private func synthesizeWithRegularService(
        text: String,
        language: TTSLanguage,
        speakingRate: Double,
        pitch: Double,
        voice: TTSVoice?,
        useSSMLPauses: Bool
    ) async throws -> Data {
        googleTTSService.useSSMLPauses = useSSMLPauses
        return try await googleTTSService.synthesizeSpeech(
            text: text,
            language: language,
            speakingRate: speakingRate,
            pitch: pitch,
            voice: voice
        )
    }
    
    private func synthesizeWithLongAudioService(
        text: String,
        language: TTSLanguage,
        speakingRate: Double,
        pitch: Double,
        voice: TTSVoice?
    ) async throws -> Data {
        // Generate unique output filename for mounted GCS bucket
        let timestamp = Int(Date().timeIntervalSince1970)
        let randomId = UUID().uuidString.prefix(8)
        let outputFileName = "audio_\(timestamp)_\(randomId).wav"
        
        // Start long audio synthesis
        let operationId = try await longAudioService.startSynthesis(
            text: text,
            languageCode: language.code,
            voiceName: voice?.name,
            speakingRate: speakingRate,
            pitch: pitch,
            outputFileName: outputFileName
        )
        
        // Poll for completion (with timeout)
        let maxAttempts = 60 // 5 minutes max
        var attempts = 0
        
        while attempts < maxAttempts {
            let status = try await longAudioService.getStatus(operationId: operationId)
            
            if status.done {
                if let error = status.error, !error.isEmpty {
                    throw NSError(domain: "LongAudioTTSService", code: -1, userInfo: [NSLocalizedDescriptionKey: error])
                }
                
                guard let downloadUrl = status.downloadUrl else {
                    throw NSError(domain: "LongAudioTTSService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No download URL provided"])
                }
                
                // Extract filename from download URL
                let fileName = downloadUrl.components(separatedBy: "/").last ?? outputFileName
                
                // Download the completed audio
                return try await longAudioService.downloadOutput(fileName: fileName)
            }
            
            // Wait before next check
            try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            attempts += 1
        }
        
        throw NSError(domain: "LongAudioTTSService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Synthesis timeout"])
    }
}