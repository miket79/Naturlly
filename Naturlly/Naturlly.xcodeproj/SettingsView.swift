import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var lang: LanguageSettings

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "language_label")) {
                    Picker(String(localized: "language_label"), selection: $lang.selected) {
                        ForEach(AppLanguage.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "settings_title"))
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(LanguageSettings())
}
