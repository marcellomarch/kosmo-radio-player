import Foundation

/// One-time import of settings saved by the pre-rename build ("WorldRadio",
/// bundle id `com.local.WorldRadio`), so favorites, volume, language and
/// visualizer preset survive the rename to Kosmo Radio.
@MainActor
enum LegacyDefaults {
    private static let legacySuite = "com.local.WorldRadio"
    private static let doneKey = "kosmoradio_legacy_import_done"
    private static var ran = false

    static func migrateIfNeeded() {
        guard !ran else { return }
        ran = true
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: doneKey) else { return }
        defer { defaults.set(true, forKey: doneKey) }

        guard let old = UserDefaults(suiteName: legacySuite)?.dictionaryRepresentation() else { return }
        for (key, value) in old where key.hasPrefix("worldradio_") {
            let newKey = "kosmoradio_" + key.dropFirst("worldradio_".count)
            if defaults.object(forKey: newKey) == nil {
                defaults.set(value, forKey: newKey)
            }
        }
    }
}
