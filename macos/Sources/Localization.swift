import Foundation
import Combine

enum AppLanguageMode: String, CaseIterable, Identifiable {
    case system = "system"
    case it = "it"
    case en = "en"

    var id: String { rawValue }

    var displayBadge: String {
        switch self {
        case .system: return "🌐 Auto"
        case .it: return "🇮🇹 IT"
        case .en: return "🇬🇧 EN"
        }
    }
}

@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var mode: AppLanguageMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "kosmoradio_lang_mode")
        }
    }

    private init() {
        LegacyDefaults.migrateIfNeeded()
        if let saved = UserDefaults.standard.string(forKey: "kosmoradio_lang_mode"),
           let parsed = AppLanguageMode(rawValue: saved) {
            self.mode = parsed
        } else {
            self.mode = .system
        }
    }

    var isEnglish: Bool {
        switch mode {
        case .en:
            return true
        case .it:
            return false
        case .system:
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
            return !preferred.hasPrefix("it")
        }
    }

    func t(_ it: String, _ en: String) -> String {
        isEnglish ? en : it
    }
}
