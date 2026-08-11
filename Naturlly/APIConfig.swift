//
//  APIConfig.swift
//  Naturlly TTS
//
//  Centralized configuration for API defaults.
//

import Foundation

struct APIConfig {
    // Default Google TTS API Key fallback. Keep empty by default for safety.
    // If you want to ship a default key (not recommended), set it here.
    static let defaultGoogleTTSAPIKey: String = "AIzaSyAMrGuMUtpwW34-kTCf6VKH1ARUYJH_i38"
    
    // Backend configuration for Long Audio TTS Service
    // Configured for Cloud Run infrastructure with mounted GCS bucket
    static let defaultBackendURL: String = "https://backend-cloud-run-XXXX.uc.a.run.app" // Will be replaced with actual Cloud Run URL
    static let defaultGCSBucket: String = "app-data-bucket" // GCS bucket name from Terraform infrastructure
    
    // User defaults keys
    static let backendURLKey = "BackendURL"
    static let gcsBucketKey = "GCSBucket"
    static let useLongAudioServiceKey = "UseLongAudioService"
}
    

