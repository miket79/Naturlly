//
//  SettingsView.swift
//  Naturlly TTS
//
//  Settings view for API keys and service configuration
//

import SwiftUI

struct SettingsView: View {
    @Binding var apiKey: String
    @Binding var useVertexVoices: Bool
    
    @State private var backendURL: String = UserDefaults.standard.string(forKey: APIConfig.backendURLKey) ?? APIConfig.defaultBackendURL
    @State private var gcsBucket: String = UserDefaults.standard.string(forKey: APIConfig.gcsBucketKey) ?? APIConfig.defaultGCSBucket
    @State private var useLongAudioService: Bool = UserDefaults.standard.bool(forKey: APIConfig.useLongAudioServiceKey)
    
    // Estados para pruebas de conectividad
    @State private var isTestingBackend = false
    @State private var backendTestResult: String?
    @State private var backendTestSuccess: Bool?
    @State private var isTestingGCS = false
    @State private var gcsTestResult: String?
    @State private var gcsTestSuccess: Bool?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(String(localized: "settings.section_gcloud"))) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "settings.api_key_label"))
                            .font(.headline)
                        
                        TextField(String(localized: "settings.api_key_placeholder"), text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Text(String(localized: "settings.api_key_hint"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle(String(localized: "settings.vertex_toggle"), isOn: $useVertexVoices)
                        .onChange(of: useVertexVoices) { _, _ in
                            saveVertexPreference()
                        }
                }
                
                Section(header: Text(String(localized: "settings.long_audio_section"))) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "settings.backend_url_label"))
                            .font(.headline)
                        
                        TextField("https://backend-cloud-run-XXXX.uc.a.run.app", text: $backendURL)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Text(String(localized: "settings.backend_url_hint"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "settings.gcs_bucket_label"))
                            .font(.headline)
                        
                        TextField("app-data-bucket", text: $gcsBucket)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Text(String(localized: "settings.gcs_bucket_hint"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle(String(localized: "settings.long_audio_toggle"), isOn: $useLongAudioService)
                        .onChange(of: useLongAudioService) { _, _ in
                            saveLongAudioPreference()
                        }
                    
                    if useLongAudioService {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "settings.service_info_title"))
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            
                            Text(String(localized: "settings.service_info_desc"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text(String(localized: "settings.connectivity_section"))) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "settings.connectivity_desc"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Prueba del Backend
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(String(localized: "settings.backend_vm"))
                                    .font(.headline)
                                
                                if let result = backendTestResult {
                                    Text(result)
                                        .font(.caption)
                                        .foregroundColor(backendTestSuccess == true ? .green : .red)
                                } else {
                                    Text(String(localized: "status.not_tested"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: { testBackendConnection() }) {
                                if isTestingBackend {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                } else {
                                    Text(String(localized: "btn.test"))
                                        .fontWeight(.semibold)
                                }
                            }
                            .disabled(isTestingBackend || backendURL.isEmpty)
                            .buttonStyle(.bordered)
                            .tint(.blue)
                        }
                        
                        // Prueba del Bucket GCS
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(String(localized: "settings.gcs_bucket_test"))
                                    .font(.headline)
                                
                                if let result = gcsTestResult {
                                    Text(result)
                                        .font(.caption)
                                        .foregroundColor(gcsTestSuccess == true ? .green : .red)
                                } else {
                                    Text(String(localized: "status.not_tested"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: { testGCSConnection() }) {
                                if isTestingGCS {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                } else {
                                    Text(String(localized: "btn.test"))
                                        .fontWeight(.semibold)
                                }
                            }
                            .disabled(isTestingGCS || gcsBucket.isEmpty)
                            .buttonStyle(.bordered)
                            .tint(.green)
                        }
                        
                        // Estado general de configuración
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "settings.config_status_section"))
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            
                            HStack(spacing: 12) {
                                Image(systemName: apiKey.isEmpty ? "xmark.circle.fill" : "checkmark.circle.fill")
                                    .foregroundColor(apiKey.isEmpty ? .red : .green)
                                
                                Text(String(localized: "settings.api_key_configured"))
                                    .font(.caption)
                            }
                            
                            HStack(spacing: 12) {
                                Image(systemName: backendURL != APIConfig.defaultBackendURL ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(backendURL != APIConfig.defaultBackendURL ? .green : .red)
                                
                                Text(String(localized: "settings.backend_configured"))
                                    .font(.caption)
                            }
                            
                            HStack(spacing: 12) {
                                Image(systemName: gcsBucket != APIConfig.defaultGCSBucket ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(gcsBucket != APIConfig.defaultGCSBucket ? .green : .red)
                                
                                Text(String(localized: "settings.bucket_configured"))
                                    .font(.caption)
                            }
                            
                            HStack(spacing: 12) {
                                Image(systemName: useLongAudioService ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(useLongAudioService ? .green : .red)
                                
                                Text(String(localized: "settings.long_audio_enabled"))
                                    .font(.caption)
                            }
                        }
                        .padding(8)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                }
                
                Section(header: Text("Instrucciones de Configuración")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Para usar el servicio de audio largo:")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1. **Configura tu VM en Google Cloud:**")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            
                            Text("   • Crea una VM con Node.js o Python")
                            Text("   • Implementa los endpoints del LongAudioTTSService")
                            Text("   • Configura credenciales de Google Cloud")
                            
                            Text("2. **Configura Google Cloud Storage:**")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            
                            Text("   • Crea un bucket para almacenar audio")
                            Text("   • Otorga permisos a tu VM para escribir en el bucket")
                            
                            Text("3. **Endpoints requeridos:**")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            
                            Text("   • POST /tts/long/start")
                            Text("   • GET /tts/long/status")
                            Text("   • GET /tts/long/download")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(String(localized: "settings.nav_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "btn.save")) {
                        saveSettings()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "btn.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(apiKey, forKey: "GoogleTTSAPIKey")
        UserDefaults.standard.set(backendURL, forKey: APIConfig.backendURLKey)
        UserDefaults.standard.set(gcsBucket, forKey: APIConfig.gcsBucketKey)
        UserDefaults.standard.set(useLongAudioService, forKey: APIConfig.useLongAudioServiceKey)
        UserDefaults.standard.set(useVertexVoices, forKey: "UseVertexVoices")
    }
    
    private func saveVertexPreference() {
        UserDefaults.standard.set(useVertexVoices, forKey: "UseVertexVoices")
    }
    
    private func saveLongAudioPreference() {
        UserDefaults.standard.set(useLongAudioService, forKey: APIConfig.useLongAudioServiceKey)
    }
    
    private func testBackendConnection() {
        guard let url = URL(string: backendURL) else {
            backendTestResult = "URL inválida"
            backendTestSuccess = false
            return
        }
        
        isTestingBackend = true
        backendTestResult = nil
        
        Task {
            do {
                // Crear una URL de prueba para verificar conectividad básica
                let testURL = url.appendingPathComponent("tts/long/status")
                var request = URLRequest(url: testURL)
                request.httpMethod = "GET"
                request.timeoutInterval = 10 // 10 segundos timeout
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    await MainActor.run {
                        if (200...299).contains(httpResponse.statusCode) {
                            backendTestResult = "✅ Conexión exitosa (HTTP \(httpResponse.statusCode))"
                            backendTestSuccess = true
                        } else {
                            backendTestResult = "⚠️ Respuesta inesperada (HTTP \(httpResponse.statusCode))"
                            backendTestSuccess = false
                        }
                    }
                } else {
                    await MainActor.run {
                        backendTestResult = "✅ Conexión establecida"
                        backendTestSuccess = true
                    }
                }
            } catch {
                await MainActor.run {
                    backendTestResult = "❌ Error de conexión: \(error.localizedDescription)"
                    backendTestSuccess = false
                }
            }
            
            await MainActor.run {
                isTestingBackend = false
            }
        }
    }
    
    private func testGCSConnection() {
        // Para probar GCS, intentamos hacer una petición al bucket público
        // Esto es una prueba básica - en producción necesitarías credenciales
        let testURLString = "https://storage.googleapis.com/storage/v1/b/\(gcsBucket)/o"
        
        guard let url = URL(string: testURLString) else {
            gcsTestResult = "Nombre de bucket inválido"
            gcsTestSuccess = false
            return
        }
        
        isTestingGCS = true
        gcsTestResult = nil
        
        Task {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.timeoutInterval = 10
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    await MainActor.run {
                        if httpResponse.statusCode == 200 {
                            gcsTestResult = "✅ Bucket accesible (HTTP \(httpResponse.statusCode))"
                            gcsTestSuccess = true
                        } else if httpResponse.statusCode == 403 {
                            gcsTestResult = "⚠️ Bucket existe pero acceso restringido (HTTP 403)"
                            gcsTestSuccess = true // El bucket existe, solo es privado
                        } else if httpResponse.statusCode == 404 {
                            gcsTestResult = "❌ Bucket no encontrado (HTTP 404)"
                            gcsTestSuccess = false
                        } else {
                            gcsTestResult = "⚠️ Respuesta inesperada (HTTP \(httpResponse.statusCode))"
                            gcsTestSuccess = false
                        }
                    }
                } else {
                    await MainActor.run {
                        gcsTestResult = "✅ Conexión a GCS establecida"
                        gcsTestSuccess = true
                    }
                }
            } catch {
                await MainActor.run {
                    gcsTestResult = "❌ Error de conexión: \(error.localizedDescription)"
                    gcsTestSuccess = false
                }
            }
            
            await MainActor.run {
                isTestingGCS = false
            }
        }
    }
}