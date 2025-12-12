//
//  TTSRequest.swift
//  Naturlly TTS
//
//  Google TTS API Request Model
//

import Foundation

struct TTSRequest: Codable {
    let input: TextInput
    let voice: VoiceSelection
    let audioConfig: AudioConfig
    
    struct TextInput: Codable {
        let text: String?
        let ssml: String?
        
        init(text: String) {
            self.text = text
            self.ssml = nil
        }
        
        init(ssml: String) {
            self.text = nil
            self.ssml = ssml
        }
    }
    
    struct VoiceSelection: Codable {
        let languageCode: String
        let name: String
    }
    
    struct AudioConfig: Codable {
        let audioEncoding: String
        let speakingRate: Double
        let pitch: Double
        
        enum CodingKeys: String, CodingKey {
            case audioEncoding
            case speakingRate
            case pitch
        }
    }
}

struct TTSResponse: Codable {
    let audioContent: String
}
