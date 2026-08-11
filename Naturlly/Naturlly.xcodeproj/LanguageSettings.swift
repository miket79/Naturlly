import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system // use system language
    case en
    case es
    case fr
    case pt
    case it
    case de

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return String(localized: "system_language")
        case .en: return "English"
        case .es: return "Español"
        case .fr: return "Français"
        case .pt: return "Português"
        case .it: return "Italiano"
        case .de: return "Deutsch"
        }
    }

    var locale: Locale? {
        switch self {
        case .system: return nil
        case .en: return Locale(identifier: "en")
        case .es: return Locale(identifier: "es")
        case .fr: return Locale(identifier: "fr")
        case .pt: return Locale(identifier: "pt")
        case .it: return Locale(identifier: "it")
        case .de: return Locale(identifier: "de")
        }
    }
}

final class LanguageSettings: ObservableObject {
    @AppStorage("app.language") private var storedLanguage: String = AppLanguage.system.rawValue
    @Published var selected: AppLanguage = .system {
        didSet { storedLanguage = selected.rawValue }
    }

    init() {
        selected = AppLanguage(rawValue: storedLanguage) ?? .system
    }

    var effectiveLocale: Locale? {
        selected.locale
    }
}
