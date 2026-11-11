import Foundation
import Combine

/// What the listener told us in the onboarding: the music families and places
/// that get their own sidebar sections, in the order they were picked.
@MainActor
final class ListenerProfile: ObservableObject {
    static let shared = ListenerProfile()

    @Published private(set) var familyIDs: [String]
    @Published private(set) var placeIDs: [String]
    @Published private(set) var isCompleted: Bool
    /// Drives the onboarding sheet; also set from "Personalize Kosmo Radio…".
    @Published var isOnboardingPresented = false

    private static let key = "kosmoradio_profile_v1"

    private struct Stored: Codable {
        var families: [String]
        var places: [String]
    }

    private init() {
        LegacyDefaults.migrateIfNeeded()
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Self.key),
           let stored = try? JSONDecoder().decode(Stored.self, from: data) {
            familyIDs = stored.families.filter { Catalog.family(id: $0) != nil }
            placeIDs = stored.places.filter { Catalog.place(id: $0) != nil }
            isCompleted = true
        } else if let data = defaults.data(forKey: "kosmoradio_favorites_v1"),
                  let saved = try? JSONDecoder().decode([RadioStation].self, from: data),
                  !saved.isEmpty {
            // Existing listener from before the onboarding: keep the layout they know.
            familyIDs = ["hiphop"]
            placeIDs = ["UA", "nyc"]
            isCompleted = true
            save()
        } else {
            familyIDs = []
            placeIDs = []
            isCompleted = false
            isOnboardingPresented = true
        }
    }

    var families: [GenreFamily] { familyIDs.compactMap(Catalog.family(id:)) }
    var places: [Place] { placeIDs.compactMap(Catalog.place(id:)) }
    var otherFamilies: [GenreFamily] { Catalog.families.filter { !familyIDs.contains($0.id) } }
    var otherPlaces: [Place] { Catalog.places.filter { !placeIDs.contains($0.id) } }

    /// The section the main window opens on.
    var homeSection: SidebarSection {
        if let first = families.first { return .style(first.all) }
        if let place = places.first { return .place(place) }
        return .favorites
    }

    func update(families: [String], places: [String]) {
        familyIDs = families
        placeIDs = places
        isCompleted = true
        save()
    }

    private func save() {
        let stored = Stored(families: familyIDs, places: placeIDs)
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    /// A few stations for each pick, to fill Favorites: hand-picked ones when we
    /// have them, otherwise the most popular on Radio Browser.
    func starterStations(perPick: Int = 3) async -> [RadioStation] {
        var result: [RadioStation] = []
        func add(_ list: [RadioStation]) {
            for s in list.prefix(perPick) where !result.contains(where: { $0.streamURL == s.streamURL }) {
                result.append(s)
            }
        }
        for family in families {
            if !family.all.curatedStations.isEmpty {
                add(family.all.curatedStations)
            } else if let remote = try? await RadioBrowserService.shared.searchStations(tag: family.all.tag, limit: 10) {
                add(remote)
            }
        }
        for place in places {
            if !place.curatedStations.isEmpty {
                add(place.curatedStations)
            } else if let remote = try? await RadioBrowserService.shared.searchStations(
                countryCode: place.countryCode, state: place.state, limit: 10
            ) {
                add(remote)
            }
        }
        return result
    }
}
