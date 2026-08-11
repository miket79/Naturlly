import Foundation
import Combine

class LanguageSettings: ObservableObject {
    @Published var effectiveLocale: Locale? = nil
    
    // Future settings can be added here, e.g.:
    // @Published var preferredVoiceLanguage: String? = nil
    
    func updateLocale(to locale: Locale?) {
        effectiveLocale = locale
    }
}
